require "json"
require "fileutils"

class XcodeProjectUpdater
	def initialize()
        @base_target = $base_project.targets.first
        @target = $project.targets.first

        @group_root_path = 'SDK'
		@group_sub_path = @group_root_path

		@unity_class_group = new_group(File.join(@group_root_path), PROJECT_RESOURCE_PATH)

        #怎么这里获取的是个字符串？
        @framework_search_paths_array = [
            "$(inherited)",
        ]
		@framework_search_paths_array.insert(@framework_search_paths_array.size, PROJECT_RESOURCE_PATH)
        puts @framework_search_paths_array
        
        @header_search_paths_array = Array.new
        @header_search_paths_array = get_build_setting(@base_target, "HEADER_SEARCH_PATHS")
		@header_search_paths_array.insert(@header_search_paths_array.size - 1, PROJECT_RESOURCE_PATH)
        
        @library_search_paths_array = Array.new
		@library_search_paths_array = get_build_setting(@base_target, "LIBRARY_SEARCH_PATHS")
		@library_search_paths_array.insert(@library_search_paths_array.size - 1, PROJECT_RESOURCE_PATH)

		config = File.read($config_path)
		@setting_hash = JSON.parse(config)
	end

	def start()
		#移除所有旧的引用
		if !@unity_class_group.empty?
			remove_build_phase_files_recursively(@target, @unity_class_group)
			@unity_class_group.clear()
		end 

		if $project.frameworks_group['iOS'] and !$project.frameworks_group['iOS'].empty? 
			remove_build_phase_files_recursively(@target, $project.frameworks_group['iOS'])
			$project.frameworks_group['iOS'].clear()		
		end 

		#新增引用
		add_build_phase_files(@target, @unity_class_group, PROJECT_RESOURCE_PATH, @target.new_copy_files_build_phase("Embed Frameworks"))
	
		#新增相关查找路径
		set_search_path()

		#配置json文件
		set_build_settings_form_config()
	end 

	def remove_build_phase_files_recursively(target, group)
		group.groups.each do |sub_group|
			remove_build_phase_files_recursively(target, sub_group)
		end 

		group.files.each do |file|
			if file.real_path.to_s.end_with?(".m", ".mm", ".cpp") 
				target.source_build_phase.remove_file_reference(file)
			elsif file.real_path.to_s.end_with?(".framework", ".a") 
				target.frameworks_build_phases.remove_file_reference(file)
			elsif file.real_path.to_s.end_with?(".bundle", ".jpg", ".png") 
				target.resources_build_phase.remove_file_reference(file)
			end
		end 
	end 

	def add_build_phase_files(target, group, path, embedFrameworks)
		Dir.foreach(path) do |dir|
			newPath = "#{path}/#{dir}"
        
            #Classes为特殊文件夹-过滤
			if dir != '.' and dir != '..' and dir != ".DS_Store" 
				file_type = File::ftype(newPath)

				if dir == "Copy"
                    replace_need_copy_files(newPath)
                elsif newPath.to_s.end_with?("Unity-iPhone")
                    copy_unity_iphone_folder(newPath)
				elsif file_type == "directory" and !newPath.to_s.end_with?(".bundle", ".framework")
                    @framework_search_paths_array.insert(@framework_search_paths_array.size - 1, newPath)
                    @header_search_paths_array.insert(@header_search_paths_array.size - 1, newPath)
                    @library_search_paths_array.insert(@library_search_paths_array.size - 1, newPath)

					parent_path = @group_sub_path
					@group_sub_path = "#{@group_sub_path}/#{dir}"
					new_group = new_group(File.join(@group_sub_path), newPath)
					
					add_build_phase_files(target, new_group, newPath, embedFrameworks)

					@group_sub_path = parent_path				
				else
					file_ref = group.new_reference(newPath)
					if newPath.to_s.end_with?(".m", ".mm", ".cpp") 
						target.source_build_phase.add_file_reference(file_ref)
					elsif newPath.to_s.end_with?(".framework", ".a") 
						target.frameworks_build_phases.add_file_reference(file_ref)
						
						if is_embedFrameworks(newPath)
							embedFrameworks.add_file_reference(file_ref)
						end

					elsif newPath.to_s.end_with?(".bundle", ".jpg", ".png") 
						target.resources_build_phase.add_file_reference(file_ref)
					end
				end
			end
		end 
	end 

	#新增framework查找路径
	def set_search_path()
		set_build_setting(@target, "FRAMEWORK_SEARCH_PATHS", @framework_search_paths_array)
		set_build_setting(@target, "HEADER_SEARCH_PATHS", @header_search_paths_array)
		set_build_setting(@target, "LIBRARY_SEARCH_PATHS", @library_search_paths_array)
	end 

	#覆盖Copy文件夹中的文件UI
	def replace_need_copy_files(mod_path)
		h_file_path = "#{mod_path}/UnityAppController.h"
		m_file_path = "#{mod_path}/UnityAppController.mm"
        info_file_path = "#{mod_path}/Info.plist"
        export_plist_path = "#{mod_path}/ExportOptions.plist"
        
        #copy ExportOptions
        if File::exist?(export_plist_path)
            FileUtils.cp export_plist_path, "#{$project_folder_path}"
        end
        
        #copy Info
        if File::exist?(info_file_path)
            FileUtils.cp info_file_path, "#{$project_folder_path}"
        end
        
		if File::exist?(h_file_path)
			FileUtils.cp h_file_path, "#{$project_folder_path}/Classes"
		end

		if File::exist?(m_file_path)
			FileUtils.cp m_file_path, "#{$project_folder_path}/Classes"
		end
	end 

	#用于替换图标和LaunchImage图
	def copy_unity_iphone_folder(path)
		FileUtils.cp_r path, $project_folder_path
	end

	#解析配置文件(新增系统相关库)
	def set_build_settings_form_config()

		frameworks = @setting_hash["frameworks"]
		libs = @setting_hash["Libs"]
		linker_flags = @setting_hash["linker_flags"]
		bundle_identifier = @setting_hash["product_bundle_identifier"]
		
    	#新增系统framework
		@target.add_system_frameworks(frameworks)

		#新增lib(tbd)
		@target.add_system_library_tbd(libs)

		#设置linker_flags
        linker_flags.insert(linker_flags.size - 1, "$(inherited)")
        linker_flags.insert(linker_flags.size - 1, "-weak_framework")
        linker_flags.insert(linker_flags.size - 1, "CoreMotion")
        linker_flags.insert(linker_flags.size - 1, "-weak-lSystem")
        set_build_setting(@target, "OTHER_LDFLAGS", linker_flags)

		#设置证书信息
		develop_signing_identity = @setting_hash["develop_signing_identity"]
		set_build_setting(@target, "PROVISIONING_PROFILE_SPECIFIER", develop_signing_identity[0], "Debug")
		set_build_setting(@target, "DEVELOPMENT_TEAM", develop_signing_identity[1], "Debug")
		set_build_setting(@target, "CODE_SIGN_IDENTITY[sdk=iphoneos*]", "iPhone Developer", "Debug")
        set_build_setting(@target, "PRODUCT_BUNDLE_IDENTIFIER", bundle_identifier, "Debug")

		release_signing_identity = @setting_hash["release_signing_identity"]
		set_build_setting(@target, "PROVISIONING_PROFILE_SPECIFIER", release_signing_identity[0], "Release")
		set_build_setting(@target, "DEVELOPMENT_TEAM", release_signing_identity[1], "Release")
		set_build_setting(@target, "CODE_SIGN_IDENTITY[sdk=iphoneos*]", "iPhone Distribution", "Release")
        set_build_setting(@target, "PRODUCT_BUNDLE_IDENTIFIER", bundle_identifier, "Release")

		enable_bitCode = @setting_hash["enable_bit_code"]
		set_build_setting(@target, "ENABLE_BITCODE", enable_bitCode)
	end

	#新增一个xcode-group
	def new_group(path, relation_path)
		unity_class_group = $project.main_group.find_subpath(path, true)
		unity_class_group.set_source_tree('<group>')
		unity_class_group.set_path(relation_path)
		return unity_class_group
	end 

	def set_build_setting(target, key, value, build_configuration_name = "All")
		target.build_configurations.each do |config|
			if build_configuration_name == "All" || build_configuration_name == config.to_s then
				build_settings = config.build_settings
				build_settings[key] = value
			end
		end 
	end

	def get_build_setting(target, key, build_configuration_name = "All")
		target.build_configurations.each do |config|
			if build_configuration_name == "All" || build_configuration_name == config.to_s then
				build_settings = config.build_settings
				return build_settings[key]
			end
		end 
	end 

	def is_embedFrameworks(newPath)
		embedArray = @setting_hash["embedFrameworks"]
		for item in embedArray
			if newPath.include?item
				return true
			end
		end
		return false
	end
end
