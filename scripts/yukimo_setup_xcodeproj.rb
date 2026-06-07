#!/usr/bin/env ruby
# yukimo_setup_xcodeproj.rb
#
# One-shot configurator: enables Swift in the AniAnglia target and registers
# every file under AniAnglia/Yukimo/ in the project. Idempotent — safe to
# re-run after adding more Yukimo files.
#
#   ruby scripts/yukimo_setup_xcodeproj.rb
#

require 'xcodeproj'
require 'pathname'

PROJECT_PATH = File.expand_path('../AniAnglia.xcodeproj', __dir__)
TARGET_NAME  = 'AniAnglia'
YUKIMO_ROOT  = File.expand_path('../AniAnglia/Yukimo', __dir__)
BRIDGING_HDR = 'AniAnglia/Yukimo/Bridge/Yukimo-Bridging-Header.h'

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target #{TARGET_NAME} not found" unless target

# ---------------------------------------------------------------------------
# 1) Swift build settings on EVERY config (Debug + Release of the target).
# ---------------------------------------------------------------------------
swift_settings_common = {
  'SWIFT_VERSION'                          => '5.0',
  'SWIFT_OBJC_BRIDGING_HEADER'             => BRIDGING_HDR,
  'SWIFT_OBJC_INTERFACE_HEADER_NAME'       => 'AniAnglia-Swift.h',
  'PRODUCT_MODULE_NAME'                    => 'AniAnglia',
  'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'  => 'YES',
  'SWIFT_INSTALL_OBJC_HEADER'              => 'YES',
  'DEFINES_MODULE'                         => 'NO',
  'SWIFT_EMIT_LOC_STRINGS'                 => 'YES',
  'CLANG_ENABLE_MODULES'                   => 'YES',
  # Yukimo redesign needs @Observable (iOS 17+), NavigationStack (iOS 16+),
  # symbolEffect (iOS 17+). Bump deployment target to 17.0 — Sabirov device
  # runs iOS 26.3.1 so this is more than safe.
  'IPHONEOS_DEPLOYMENT_TARGET'             => '17.0'
}

target.build_configurations.each do |cfg|
  cfg.build_settings.merge!(swift_settings_common)
  if cfg.name == 'Debug'
    cfg.build_settings['SWIFT_OPTIMIZATION_LEVEL']       = '-Onone'
    cfg.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    cfg.build_settings['SWIFT_COMPILATION_MODE']         = 'singlefile'
  else
    cfg.build_settings['SWIFT_OPTIMIZATION_LEVEL']       = '-O'
    cfg.build_settings['SWIFT_COMPILATION_MODE']         = 'wholemodule'
  end
end
puts "✓ Swift settings written to #{target.build_configurations.size} target configs"

# ---------------------------------------------------------------------------
# 2) Build the AniAnglia/Yukimo/* group tree to mirror the filesystem.
# ---------------------------------------------------------------------------
# Find or create the AniAnglia top-level group (its path is 'AniAnglia').
anianglia_group = project.main_group['AniAnglia']
raise "Top-level AniAnglia group not found" unless anianglia_group

# Resolve-or-create a child group with an exact filesystem-mirrored path.
def find_or_create_group(parent, name)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name }
  return existing if existing
  parent.new_group(name, name)
end

yukimo_group = find_or_create_group(anianglia_group, 'Yukimo')

sources_phase = target.source_build_phase
# Track all references so re-runs don't duplicate.
existing_file_refs_by_path = {}
project.files.each { |f| existing_file_refs_by_path[f.real_path.to_s] = f if f.real_path }

added_count = 0
swift_files = []
mm_files    = []

Dir.glob(File.join(YUKIMO_ROOT, '**', '*')).sort.each do |entry|
  next if File.directory?(entry)
  next unless entry =~ /\.(swift|mm|h)$/

  abs = File.expand_path(entry)
  rel_from_proj = Pathname.new(abs).relative_path_from(Pathname.new(File.dirname(PROJECT_PATH))).to_s
  # rel_from_proj = "AniAnglia/Yukimo/.../Foo.swift"
  parts = rel_from_proj.split('/')
  # Skip the leading "AniAnglia/Yukimo/" (already at yukimo_group); walk the
  # remaining path segments into groups.
  subpath = parts[2..-2] || []
  group = yukimo_group
  subpath.each { |seg| group = find_or_create_group(group, seg) }

  file_name = parts[-1]
  if existing_file_refs_by_path[abs]
    ref = existing_file_refs_by_path[abs]
  else
    ref = group.new_reference(abs)
    added_count += 1
  end

  # Ensure source-compilable files are in the Sources build phase.
  if entry.end_with?('.swift', '.mm')
    unless sources_phase.files_references.include?(ref)
      sources_phase.add_file_reference(ref)
    end
  end

  swift_files << file_name if entry.end_with?('.swift')
  mm_files    << file_name if entry.end_with?('.mm')
end

puts "✓ Added #{added_count} new file references"
puts "✓ Swift sources: #{swift_files.size}, Obj-C++ bridge sources: #{mm_files.size}"

# Drop references to files that no longer exist on disk — happens when a
# Swift file is renamed or deleted manually.
removed = 0
yukimo_root_abs = File.expand_path(YUKIMO_ROOT)
project.files.each do |f|
  next unless f.real_path
  path = f.real_path.to_s
  next unless path.start_with?(yukimo_root_abs)
  unless File.exist?(path)
    # Remove from build phases first.
    project.targets.each do |t|
      t.build_phases.each do |bp|
        next unless bp.respond_to?(:files)
        bp.files.dup.each do |bf|
          bp.remove_build_file(bf) if bf.file_ref == f
        end
      end
    end
    f.remove_from_project
    removed += 1
  end
end
puts "✓ Removed #{removed} stale file references"

project.save
puts "✓ Project saved: #{PROJECT_PATH}"
