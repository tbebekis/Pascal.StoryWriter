unit fr_QuickView;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , ExtCtrls
  , ComCtrls
  , Contnrs
  , Menus
  , LCLType
  , LCLIntf
  , DB
  , DBCtrls
  , DBGrids
  , fr_FramePage
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities
  , fr_TextEditor
  ;

type

  { TfrQuickView }

  TfrQuickView = class(TFramePage)
    frText: TfrTextEditor;
    Grid: TDBGrid;
    pnlBottom: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    ToolBar: TToolBar;
  private
    tblList: TMemTable;
    DS : TDatasource;
    //LinkItemList: TLinkItemList;

    btnEditText: TToolButton;
    btnRemoveItem: TToolButton;
    btnRemoveAll: TToolButton;
    btnShowItemInListPage: TToolButton;
    btnUp : TToolButton;
    btnDown : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    function GetQuickView: TQuickView;

    procedure tblList_OnAfterScroll(Dataset: TDataset);

    procedure PrepareToolBar();

    procedure ReLoad();
    procedure SaveList();

    procedure ShowLinkItemPage();
    procedure RemoveLinkItem();
    procedure RemoveAllLinkItems();
    procedure ShowItemInListPage();
    procedure MoveRow(Up: Boolean);

    procedure ClearResults();
    procedure SelectedLinkItemRowChanged();

    procedure EnsureTable();
    procedure DisposeTable();
    procedure AddToTable(LinkItem: TLinkItem);
    function  GetId(): string;
    procedure GotToId(const Id: string);
    function  GetItem(): TLinkItem;
  protected
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    procedure AddToQuickView(LinkItem: TLinkItem);

    property QuickView: TQuickView read GetQuickView;
  end;

implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_Consts
  ,o_App
  ;

{ TfrQuickView }


constructor TfrQuickView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TfrQuickView.Destroy();
begin
  inherited Destroy();
end;

procedure TfrQuickView.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Quick View';

  PrepareToolBar();

  frText.ToolBarVisible := False;
  frText.Editor.ReadOnly := True;

  ReLoad();
end;

procedure TfrQuickView.ControlInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

procedure TfrQuickView.OnBroadcasterEvent(Args: TBroadcasterArgs);
   // -------------------------------------
   procedure ItemChanged();
   var
     LinkItem: TLinkItem;
   begin
     if Args.Sender = Self then
       Exit;

     LinkItem := GetItem();
     if not Assigned(LinkItem) then
       Exit;

     if (not Assigned(tblList)) or tblList.IsEmpty then
       Exit;

     if tblList.Locate('Id', Id, []) then
     begin
       tblList.Edit();
       tblList.FieldByName('Name').AsString := LinkItem.Title;
       tblList.Post();
     end;

   end;
   // -------------------------------------
   procedure ItemListChanged(ItemType: TItemType);
   begin
     if Args.Sender = Self then
       Exit;
     ReLoad();
   end;

   // -------------------------------------
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekProjectOpened :
    begin
      ClearResults();
      ReLoad();
    end;
    aekProjectClosed : ClearResults();
    aekItemListChanged: ItemListChanged(TItemType(TBroadcasterIntegerArgs(Args).Value));     // (TItemType(TBroadcasterIntegerArgs(Args).Value));
    aekItemChanged: ItemChanged();             // (TBaseItem(Args.Data));
    //aekSearchTermIsSet: AppOnSearchTermIsSet(Args);     // (string(TBroadcasterTextArgs(Args).Value));
    //aekCategoryListChanged: AppOnCategoryListChanged(Args);
    //aekTagListChanged: AppOnTagListChanged(Args);
    //aekComponentListChanged: AppOnComponentListChanged(Args);
    //aekProjectMetricsChanged: AppOnProjectMetricsChanged(Args);
  end;
end;

procedure TfrQuickView.AddToTable(LinkItem: TLinkItem);
begin
 tblList.Append();
 tblList.FieldByName('Id').AsString := LinkItem.Id;
 tblList.FieldByName('Type').AsString := ItemTypeToString(LinkItem.ItemType);
 tblList.FieldByName('Place').AsString := LinkPlaceToString(LinkItem.Place);
 tblList.FieldByName('Name').AsString := LinkItem.Title;
 tblList.Post();
end;

function TfrQuickView.GetId(): string;
begin
  Result := '';
  if Assigned(tblList) and (not tblList.IsEmpty) then
    Result := tblList.FieldByName('Id').AsString;
end;

function TfrQuickView.GetItem(): TLinkItem;
var
  Id : string;
begin
  Result := nil;
  if not Assigned(App.CurrentProject) then
    Exit;

  Id := GetId();
  if Id <> '' then
    Result := QuickView.FindById(Id);
end;

procedure TfrQuickView.GotToId(const Id: string);
begin
  if (Id <> '') and Assigned(tblList) and (not tblList.IsEmpty)  then
    tblList.Locate('Id', Id, []);
end;

procedure TfrQuickView.EnsureTable();
begin
  if not Assigned(tblList) then
  begin
    tblList := TMemTable.Create(Self);
    tblList.FieldDefs.Add('Id', ftString, 100);
    tblList.FieldDefs.Add('Type', ftString, 100);
    tblList.FieldDefs.Add('Place', ftString, 100);
    tblList.FieldDefs.Add('Name', ftString, 200);
    tblList.CreateDataset;

    DS := TDataSource.Create(Self);
    DS.DataSet := tblList;

    Grid.Columns.Clear();
    App.AddColumn(Grid, 'Type', 'Type');
    App.AddColumn(Grid, 'Place', 'Place');
    App.AddColumn(Grid, 'Name', 'Name');
    Grid.DataSource := DS;

    App.InitializeReadOnly(Grid);
    App.AdjustGridColumns(Grid);

    tblList.Active := True;
    tblList.AfterScroll := tblList_OnAfterScroll;
  end;
end;

procedure TfrQuickView.DisposeTable();
begin
  Grid.Columns.Clear();
  Grid.DataSource := nil;
  if Assigned(DS) then
    DS.DataSet := nil;

  if Assigned(tblList) then
  begin
    tblList.AfterScroll := nil;
    tblList.Active := False;
    tblList.Free();
    tblList := nil;
  end;
end;

procedure TfrQuickView.ReLoad();
var
  Id : string;
  Item: TLinkItem;
  ListCount, i: Integer;
  ListToDelete: TObjectList;
  Message: string;
begin
  Id := GetId();
  DisposeTable();
  EnsureTable();

  if not Assigned(App.CurrentProject) then
    Exit;

  QuickView.Load();

  ListToDelete := TObjectList.Create(False);
  try
    ListCount := QuickView.List.Count;

    for i := 0 to QuickView.List.Count - 1 do
    begin
      QuickView.List[i].LoadItem();
      if not Assigned(QuickView.List[i].Item) then
        ListToDelete.Add(QuickView.List[i]);
    end;

    for i := 0 to ListToDelete.Count - 1 do
      QuickView.List[i].Free();

    // if needs saving, save the list
    if ListCount <> QuickView.List.Count then
      QuickView.Save();

    tblList.DisableControls;
    try
      tblList.EmptyDataSet;
      for i := 0 to QuickView.List.Count - 1 do
      begin
        Item := QuickView.List[i] as TLinkItem;
        AddToTable(Item);
      end;

      Message := Format('Quick View List loaded from: %s', [App.CurrentProject.QuickViewListFilePath]);
      LogBox.AppendLine(Message);
    finally
      tblList.EnableControls;
      tblList.First;
    end;

  finally
    ListToDelete.Free();
  end;

  GotToId(Id);
  SelectedLinkItemRowChanged();
end;

procedure TfrQuickView.SaveList();
var
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  QuickView.Save();
  Message := Format('Quick View List saved to: %s', [App.CurrentProject.QuickViewListFilePath]);
  LogBox.AppendLine(Message);
end;

procedure TfrQuickView.AddToQuickView(LinkItem: TLinkItem);
var
  i : Integer;
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  // check if it is already in quick view
  for i := 0 to QuickView.List.Count - 1 do
      if LinkItem.Item.Id = QuickView.List[i].Item.Id then
      begin
        Message := Format('Item is already in Quick View: %s', [LinkItem.Title]);
        LogBox.AppendLine(Message);
        Exit;
      end;

  LinkItem.Collection := QuickView.List;
  AddToTable(LinkItem);

  SaveList();

  Message := Format('Item is added to Quick View: %s', [LinkItem.Title]);
  LogBox.AppendLine(Message);

  SelectedLinkItemRowChanged();
end;

procedure TfrQuickView.SelectedLinkItemRowChanged();
var
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Id := GetId();
  LinkItem := GetItem();
  if Assigned(LinkItem) then
  begin
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frText.Editor);
    Application.ProcessMessages();
  end else begin
    pnlTitle.Caption := 'No selection';
    frText.EditorText := '';
  end;

end;

procedure TfrQuickView.ShowLinkItemPage();
var
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  App.ShowLinkItemPage(LinkItem);
end;

procedure TfrQuickView.RemoveLinkItem();
var
  LinkItem: TLinkItem;

begin
  if not Assigned(App.CurrentProject) then
    Exit;

  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  QuickView.List.Delete(LinkItem.Index);

  SaveList();
  ReLoad();

end;

procedure TfrQuickView.RemoveAllLinkItems();
begin
  if not Assigned(App.CurrentProject) then
    Exit;
  if QuickView.List.Count = 0 then
    Exit;

  if not App.QuestionBox('Are you sure you want to remove all items from Quick View?') then
    Exit;

  ClearResults();
end;

procedure TfrQuickView.ShowItemInListPage();
var
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;
  if QuickView.List.Count = 0 then
    Exit;

  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  App.ShowItemInListPage(LinkItem);

end;

procedure TfrQuickView.MoveRow(Up: Boolean);
var
  Id : string;
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblList) then
    Exit;

  if tblList.IsEmpty then
    Exit;

  Id := GetId();
  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  if LinkItem.Move(Up) then
  begin
    ReLoad();
    tblList.Locate('Id', Id, []);
  end;

end;

procedure TfrQuickView.ClearResults();
begin
  SaveList();
  ReLoad();
end;

procedure TfrQuickView.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnRemoveItem := AddButton(ToolBar, 'table_delete', 'Remove Item', AnyClick);
    btnRemoveAll := AddButton(ToolBar, 'shape_square_delete', 'Remove All', AnyClick);
    btnEditText := AddButton(ToolBar, 'page_edit', 'Edit Text', AnyClick);
    AddSeparator(ToolBar);
    btnShowItemInListPage := AddButton(ToolBar, 'table_select_row', 'Show item in its List Page', AnyClick);
    AddSeparator(ToolBar);
    btnUp := AddButton(ToolBar, 'arrow_up', 'Move Up', AnyClick);
    btnDown := AddButton(ToolBar, 'arrow_down', 'Move Down', AnyClick);
  finally
    ToolBar.Parent := P;
  end;


end;

procedure TfrQuickView.AnyClick(Sender: TObject);
begin
  if btnRemoveItem = Sender then
    RemoveLinkItem()
  else if btnRemoveAll = Sender then
    RemoveAllLinkItems()
  else if btnEditText = Sender then
    ShowLinkItemPage()
  else if btnShowItemInListPage = Sender then
    ShowItemInListPage()
  else if btnUp = Sender then
    MoveRow(True)
  else if btnDown = Sender then
    MoveRow(False);

end;

function TfrQuickView.GetQuickView: TQuickView;
begin
  Result := nil;
  if Assigned(App.CurrentProject) then
    Result := App.CurrentProject.QuickView;
end;

procedure TfrQuickView.tblList_OnAfterScroll(Dataset: TDataset);
begin
  SelectedLinkItemRowChanged();
end;












end.

