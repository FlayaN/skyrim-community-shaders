LIST(APPEND ALL_FEATURE_DEFINES "GRASS_COLLISION")
LIST(APPEND ALL_FEATURE_DEFINES "SCREEN_SPACE_SHADOWS")
LIST(APPEND ALL_FEATURE_DEFINES "LIGHT_LIMIT_FIX")
LIST(APPEND ALL_FEATURE_DEFINES "DYNAMIC_CUBEMAPS")
LIST(APPEND ALL_FEATURE_DEFINES "CLOUD_SHADOWS")

function(compile_shader FILE_REL SHADER_DEFINES)
	set(FILE "${CMAKE_BINARY_DIR}/aio/Shaders/${FILE_REL}")
	get_filename_component(FILE_DIR ${FILE} DIRECTORY)
	get_filename_component(FILE_WE ${FILE} NAME_WE)

	message("${FILE_DIR}")

	string (REPLACE ";" " /D " SHADER_DEFINES "${SHADER_DEFINES}")
    separate_arguments(SHADER_DEFINES UNIX_COMMAND "${SHADER_DEFINES}")
	string (REPLACE ";" " /D " ALL_FEATURE_DEFINES "${ALL_FEATURE_DEFINES}")
    separate_arguments(ALL_FEATURE_DEFINES UNIX_COMMAND "${ALL_FEATURE_DEFINES}")

	string(MD5 SHADER_DEFINES_HASH "${SHADER_DEFINES}")
	LIST(APPEND SHADER_STAMPS ${FILE_WE}.${SHADER_DEFINES_HASH}.stamp)
	add_custom_command(
		OUTPUT ${FILE_WE}.${SHADER_DEFINES_HASH}.stamp
		COMMAND fxc.exe /nologo /D VSHADER /D ${SHADER_DEFINES} /T vs_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND fxc.exe /nologo /D PSHADER /D ${SHADER_DEFINES} /T ps_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND fxc.exe /nologo /D VSHADER /D VR /D ${SHADER_DEFINES} /T vs_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND fxc.exe /nologo /D PSHADER /D VR /D ${SHADER_DEFINES} /T ps_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_BINARY_DIR}/${FILE_WE}.${SHADER_DEFINES_HASH}.stamp
		COMMENT "COMPILE ${FILE} WITH /D ${SHADER_DEFINES}"
		WORKING_DIRECTORY ${FILE_DIR}
		DEPENDS ${FILE}
	)

	string(MD5 SHADER_DEFINES_COMBINED_HASH "${SHADER_DEFINES};${ALL_FEATURE_DEFINES}")
	LIST(APPEND SHADER_STAMPS ${FILE_WE}.${SHADER_DEFINES_COMBINED_HASH}.stamp)
	add_custom_command(
		OUTPUT ${FILE_WE}.${SHADER_DEFINES_COMBINED_HASH}.stamp
		COMMAND fxc.exe /nologo /D VSHADER /D ${SHADER_DEFINES} /D ${ALL_FEATURE_DEFINES} /T vs_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND fxc.exe /nologo /D PSHADER /D ${SHADER_DEFINES} /D ${ALL_FEATURE_DEFINES} /T ps_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND fxc.exe /nologo /D VSHADER /D VR /D ${SHADER_DEFINES} /D ${ALL_FEATURE_DEFINES} /T vs_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND fxc.exe /nologo /D PSHADER /D VR /D ${SHADER_DEFINES} /D ${ALL_FEATURE_DEFINES} /T ps_5_0 /Emain $<IF:$<CONFIG:DEBUG>,/Od,/O1> /Zi ${FILE} > nul
		COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_BINARY_DIR}/${FILE_WE}.${SHADER_DEFINES_COMBINED_HASH}.stamp
		COMMENT "COMPILE ${FILE} WITH /D ${SHADER_DEFINES} /D ${ALL_FEATURE_DEFINES}"
		WORKING_DIRECTORY ${FILE_DIR}
		DEPENDS ${FILE}
	)

	set(SHADER_STAMPS ${SHADER_STAMPS} PARENT_SCOPE)
endfunction()