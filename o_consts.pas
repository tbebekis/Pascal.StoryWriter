unit o_Consts;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

const
  IconResourceNames: array[0..75] of string = (
    'APPLICATION_ADD',
    'APPLICATION_DELETE',
    'APPLICATION_EDIT',
    'APPLICATION_GO',
    'ARROW_DOWN',
    'ARROW_UP',
    'BOOK',
    'BOOK_ADD',
    'BOOK_EDIT',
    'BOOK_GO',
    'BOOK_LINK',
    'BOOK_OPEN',
    'BOOKSHELF',
    'BULLET_EDIT',
    'BUTTON_DEFAULT',
    'CHECK_BOX_LIST',
    'COLOR_PICKER_DEFAULT',
    'COLOR_WHEEL',
    'COMPILE',
    'DISK',
    'DOCUMENT_EXPORT',
    'DOOR_OUT',
    'ERROR_LOG',
    'FILE_EXTENSION_DOC',
    'FILE_EXTENSION_LOG',
    'FILE_EXTENSION_PDF',
    'FILE_EXTENSION_RTF',
    'FILE_EXTENSION_TXT',
    'FOLDER_EDIT',
    'FOLDER_GO',
    'FOLDER_VERTICAL_DOCUMENT',
    'FOLDER_VERTICAL_OPEN',
    'FONT_COLORS',
    'HTML',
    'INBOX_DOCUMENT_TEXT',
    'LANGUAGE',
    'LAYER_EDIT',
    'LAYOUT_SIDEBAR',
    'LINK',
    'MENU_ITEM',
    'OPEN_FOLDER',
    'PAGE_DELETE',
    'PAGE_EDIT',
    'PAGE_FIND',
    'PAGE_WHITE_EDIT',
    'PAGE_WHITE_STACK',
    'SCROLL_PANE_TREE',
    'SERVER_COMPONENTS',
    'SETTING_TOOLS',
    'SHAPE_SQUARE_DELETE',
    'SHAPE_SQUARE_EDIT',
    'SOURCE_CODE',
    'TABLE_ADD',
    'TABLE_DELETE',
    'TABLE_EDIT',
    'TABLE_EXPORT',
    'TABLE_IMPORT',
    'TABLE_INSERT',
    'TABLE_REPLACE',
    'TABLE_ROW_DELETE',
    'TABLE_ROW_INSERT',
    'TABLE_SELECT_ROW',
    'TABLE_TAB_SEARCH',
    'TEXT_BOLD',
    'TEXTFIELD_ADD',
    'TEXT_ITALIC',
    'TEXT_LINESPACING',
    'TEXT_LIST_BULLETS',
    'TEXT_LIST_NUMBERS',
    'TEXT_PADDING_TOP',
    'TEXT_REPLACE',
    'TEXT_UNDERLINE',
    'TO_DO_LIST_CHEKED_1',
    'TREE_COLLAPSE',
    'TREE_EXPAND',
    'WISHLIST_ADD'
  );

const
  { App event names }
  SProjectOpened           = 'ProjectOpened';
  SProjectClosed           = 'ProjectClosed';
  SItemListChanged         = 'ItemListChanged';
  SItemChanged             = 'ItemChanged';
  SSearchTermIsSet         = 'SearchTermIsSet';

  SCategoryListChanged     = 'CategoryListChanged';
  STagListChanged          = 'TagListChanged';
  SComponentListChanged    = 'ComponentListChanged';
  SProjectMetricsChanged   = 'ProjectMetricsChanged';



type
  { App event kind (for case) }
  TAppEventKind = (
    aekUnknown,
    aekProjectOpened,
    aekProjectClosed,
    aekItemListChanged,
    aekItemChanged,
    aekSearchTermIsSet,
    aekCategoryListChanged,
    aekTagListChanged,
    aekComponentListChanged,
    aekProjectMetricsChanged
  );



{ Converts event name to enum (case-insensitive) }
function AppEventKindOf(const Name: string): TAppEventKind;


implementation

function AppEventKindOf(const Name: string): TAppEventKind;
begin
  if SameText(Name, SProjectOpened) then Exit(aekProjectOpened);
  if SameText(Name, SProjectClosed) then Exit(aekProjectClosed);
  if SameText(Name, SItemListChanged) then Exit(aekItemListChanged);
  if SameText(Name, SItemChanged) then Exit(aekItemChanged);
  if SameText(Name, SSearchTermIsSet) then Exit(aekSearchTermIsSet);

  if SameText(Name, SCategoryListChanged) then Exit(aekCategoryListChanged);
  if SameText(Name, STagListChanged) then Exit(aekTagListChanged);
  if SameText(Name, SComponentListChanged) then Exit(aekComponentListChanged);
  if SameText(Name, SProjectMetricsChanged) then Exit(aekProjectMetricsChanged);

  Result := aekUnknown;
end;

end.

