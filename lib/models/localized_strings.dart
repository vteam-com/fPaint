/// Enum to represent the different string IDs used in the application.
enum StringId {
  menuTooltip,
  savedMessage,
  startOver,
  import,
  export,
  canvas,
  about,
  startOverTooltip,
  importTooltip,
  exportTooltip,
  platforms,
  settings,
}

/// Map containing the localized strings for each StringId.
const Map<StringId, String> strings = <StringId, String>{
  StringId.menuTooltip: 'Menu',
  StringId.savedMessage: 'Saved ',
  StringId.startOver: 'Start new...',
  StringId.import: 'Import...',
  StringId.export: 'Export...',
  StringId.canvas: 'Canvas...',
  StringId.about: 'About...',
  StringId.startOverTooltip: 'Start new...',
  StringId.importTooltip: 'Import...',
  StringId.exportTooltip: 'Export...',
  StringId.settings: 'Settings...',
  StringId.platforms: 'Available on...',
};
