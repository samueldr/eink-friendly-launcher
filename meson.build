project(
  'eink-friendly-launcher',
  'vala', 'c',
  version: '2023-04-11'
)

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
  meson.get_compiler('vala').find_library('linux'),
  dependency('gee-0.8'),
  dependency('glib-2.0'),
  dependency('gio-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk4'),
  meson.get_compiler('c').find_library('m'),
]

# Add data for use at runtime
conf = configuration_data()
conf.set_quoted('VERSION', meson.project_version())
conf.set('bindir', join_paths(get_option('prefix'), 'bin'))

configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

configure_file(
  input: 'com.samueldr.EinkFriendlyLauncher.desktop.in',
  output: 'com.samueldr.EinkFriendlyLauncher.desktop',
  configuration: conf,
  install_dir: join_paths(get_option('sysconfdir'), 'xdg/autostart')
)

# Call subdirs
subdir('src')
