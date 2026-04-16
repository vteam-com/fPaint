import 'package:fpaint/helpers/constants.dart';

/// App icon identifiers, backed by SVG assets.
enum AppIcon {
  arrowDown,
  arrowDownLeft,
  arrowDownRight,
  arrowDropDown,
  arrowLeft,
  arrowRight,
  arrowUp,
  arrowUpLeft,
  arrowUpRight,
  autoFixHigh,
  blender,
  brush,
  canvasCrop,
  check,
  checkCircle,
  circle,
  close,
  colorLens,
  colorize,
  contentPasteGo,
  copy,
  create,
  cropFree,
  cropSquare,
  download,
  edit,
  fileDownload,
  fontDownload,
  formatBold,
  formatColorFill,
  formatItalic,
  formatSize,
  highlightAlt,
  image,
  info,
  iosShare,
  keyboardDoubleArrowLeft,
  keyboardDoubleArrowRight,
  layers,
  lineAxis,
  lineStyle,
  lineWeight,
  link,
  linkOff,
  menu,
  moreVert,
  openInFull,
  outbound,
  paste,
  playlistAdd,
  playlistRemove,
  powerSettingsNew,
  redo,
  refresh,
  rotate90DegreesCw,
  rotateRight,
  settings,
  square,
  support,
  undo,
  visibility,
  visibilityOff,
  zoomIn,
  zoomOut,
}

extension AppIconAssetPath on AppIcon {
  /// Returns the SVG asset path for this icon.
  String get assetPath {
    switch (this) {
      case AppIcon.arrowDown:
        return AppIconAssets.arrowDown;
      case AppIcon.arrowDownLeft:
        return AppIconAssets.arrowDownLeft;
      case AppIcon.arrowDownRight:
        return AppIconAssets.arrowDownRight;
      case AppIcon.arrowDropDown:
        return AppIconAssets.arrowDropDown;
      case AppIcon.arrowLeft:
        return AppIconAssets.arrowLeft;
      case AppIcon.arrowRight:
        return AppIconAssets.arrowRight;
      case AppIcon.arrowUp:
        return AppIconAssets.arrowUp;
      case AppIcon.arrowUpLeft:
        return AppIconAssets.arrowUpLeft;
      case AppIcon.arrowUpRight:
        return AppIconAssets.arrowUpRight;
      case AppIcon.autoFixHigh:
        return AppIconAssets.autoFixHigh;
      case AppIcon.blender:
        return AppIconAssets.blender;
      case AppIcon.brush:
        return AppIconAssets.brush;
      case AppIcon.canvasCrop:
        return AppIconAssets.canvasCrop;
      case AppIcon.check:
        return AppIconAssets.check;
      case AppIcon.checkCircle:
        return AppIconAssets.checkCircle;
      case AppIcon.circle:
        return AppIconAssets.circle;
      case AppIcon.close:
        return AppIconAssets.close;
      case AppIcon.colorLens:
        return AppIconAssets.colorLens;
      case AppIcon.colorize:
        return AppIconAssets.colorize;
      case AppIcon.contentPasteGo:
        return AppIconAssets.contentPasteGo;
      case AppIcon.copy:
        return AppIconAssets.copy;
      case AppIcon.create:
        return AppIconAssets.create;
      case AppIcon.cropFree:
        return AppIconAssets.cropFree;
      case AppIcon.cropSquare:
        return AppIconAssets.cropSquare;
      case AppIcon.download:
        return AppIconAssets.download;
      case AppIcon.edit:
        return AppIconAssets.edit;
      case AppIcon.fileDownload:
        return AppIconAssets.fileDownload;
      case AppIcon.fontDownload:
        return AppIconAssets.fontDownload;
      case AppIcon.formatBold:
        return AppIconAssets.formatBold;
      case AppIcon.formatColorFill:
        return AppIconAssets.formatColorFill;
      case AppIcon.formatItalic:
        return AppIconAssets.formatItalic;
      case AppIcon.formatSize:
        return AppIconAssets.formatSize;
      case AppIcon.highlightAlt:
        return AppIconAssets.highlightAlt;
      case AppIcon.image:
        return AppIconAssets.image;
      case AppIcon.info:
        return AppIconAssets.info;
      case AppIcon.iosShare:
        return AppIconAssets.iosShare;
      case AppIcon.keyboardDoubleArrowLeft:
        return AppIconAssets.keyboardDoubleArrowLeft;
      case AppIcon.keyboardDoubleArrowRight:
        return AppIconAssets.keyboardDoubleArrowRight;
      case AppIcon.layers:
        return AppIconAssets.layers;
      case AppIcon.lineAxis:
        return AppIconAssets.lineAxis;
      case AppIcon.lineStyle:
        return AppIconAssets.lineStyle;
      case AppIcon.lineWeight:
        return AppIconAssets.lineWeight;
      case AppIcon.link:
        return AppIconAssets.link;
      case AppIcon.linkOff:
        return AppIconAssets.linkOff;
      case AppIcon.menu:
        return AppIconAssets.menu;
      case AppIcon.moreVert:
        return AppIconAssets.moreVert;
      case AppIcon.openInFull:
        return AppIconAssets.openInFull;
      case AppIcon.outbound:
        return AppIconAssets.outbound;
      case AppIcon.paste:
        return AppIconAssets.paste;
      case AppIcon.playlistAdd:
        return AppIconAssets.playlistAdd;
      case AppIcon.playlistRemove:
        return AppIconAssets.playlistRemove;
      case AppIcon.powerSettingsNew:
        return AppIconAssets.powerSettingsNew;
      case AppIcon.redo:
        return AppIconAssets.redo;
      case AppIcon.refresh:
        return AppIconAssets.refresh;
      case AppIcon.rotate90DegreesCw:
        return AppIconAssets.rotate90DegreesCw;
      case AppIcon.rotateRight:
        return AppIconAssets.rotateRight;
      case AppIcon.settings:
        return AppIconAssets.settings;
      case AppIcon.square:
        return AppIconAssets.square;
      case AppIcon.support:
        return AppIconAssets.support;
      case AppIcon.undo:
        return AppIconAssets.undo;
      case AppIcon.visibility:
        return AppIconAssets.visibility;
      case AppIcon.visibilityOff:
        return AppIconAssets.visibilityOff;
      case AppIcon.zoomIn:
        return AppIconAssets.zoomIn;
      case AppIcon.zoomOut:
        return AppIconAssets.zoomOut;
    }
  }
}
