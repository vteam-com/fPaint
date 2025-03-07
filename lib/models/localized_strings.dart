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

const Map<StringId, String> strings = <StringId, String>{
  StringId.menuTooltip: 'Menu',
  StringId.savedMessage: 'Saved ',
  StringId.startOver: 'Start new...',
  StringId.import: 'Import...',
  StringId.export: 'Export...',
  StringId.canvas: 'Canvas...',
  StringId.about: 'About...',
  StringId.importTooltip: 'Import...',
  StringId.exportTooltip: 'Export...',
  StringId.settings: 'Settings...',
  StringId.platforms: 'Available on...',
};
