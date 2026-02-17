unit o_Consts;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

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

