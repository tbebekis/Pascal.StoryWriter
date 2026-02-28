unit f_QuickViewForm;

{$mode DELPHI}{$H+}

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
  , Menus
  , DB
  , DBCtrls
  , DBGrids
  , f_PageForm
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities
  , f_TextEditorForm
  ;

type

  { TQuickViewForm }

  TQuickViewForm = class(TPageForm)
    Grid: TDBGrid;
    pnlBottom: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    ToolBar: TToolBar;
  private
    tblList: TMemTable;
    DS : TDatasource;

    fQuickView: TQuickView;
    frmText: TTextEditorForm;

    btnEditText: TToolButton;
    btnRemoveItem: TToolButton;
    btnRemoveAll: TToolButton;
    btnShowItemInListPage: TToolButton;
    btnUp : TToolButton;
    btnDown : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure tblList_OnAfterScroll(Dataset: TDataset);
    procedure Grid_OnDoubleClick(Sender: TObject);

    procedure PrepareToolBar();

    procedure ReLoad();
    procedure SaveList();

    procedure ShowLinkItemPage();
    procedure RemoveLinkItem();
    procedure RemoveAllLinkItems();
    procedure ShowItemInListPage();
    procedure MoveRow(Up: Boolean);

    procedure SelectedLinkItemRowChanged();

    procedure CreateTable();
    procedure EmptyTable();

    procedure AddToTable(LinkItem: TLinkItem);
    function  GetTableId(): string;
    procedure GotToTableId(const Id: string);
    function  GetItem(): TLinkItem;
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure AddToQuickView(LinkItem: TLinkItem);

  end;


implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_Consts
  ,o_App
  ;

{ TQuickViewForm }

constructor TQuickViewForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := pnlBottom;

  frmText.ToolBarVisible := False;
  frmText.TextEditor.ReadOnly := True;

  if Assigned(App.CurrentProject) then
    fQuickView := App.CurrentProject.QuickView;

  Grid.OnDblClick := Grid_OnDoubleClick;

  CreateTable();
end;

destructor TQuickViewForm.Destroy();
begin
  inherited Destroy();
end;

procedure TQuickViewForm.FormInitialize;
begin
  frmText.Visible := True;
  ParentTabPage.Caption := 'Quick View';

  PrepareToolBar();

  //Sys.RunOnce(300 * 5, Reload);
  ReLoad();
end;

procedure TQuickViewForm.FormInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

procedure TQuickViewForm.CreateTable();
begin
  tblList := TMemTable.Create(Self);

  tblList.FieldDefs.Add('Id', ftString, 100);
  tblList.FieldDefs.Add('Type', ftString, 100);
  tblList.FieldDefs.Add('Place', ftString, 100);
  tblList.FieldDefs.Add('Name', ftString, 200);
  tblList.CreateDataset;

  DS := TDataSource.Create(Self);
  DS.DataSet := tblList;

  Grid.DataSource := DS;
  Grid.OptionsExtra := Grid.OptionsExtra - [dgeAutoColumns];

  Grid.Columns.Clear();
  App.AddColumn(Grid, 'Type', 'Type');
  App.AddColumn(Grid, 'Place', 'Place');
  App.AddColumn(Grid, 'Name', 'Name');

  App.InitializeReadOnly(Grid);
  App.AdjustGridColumns(Grid);

  tblList.Active := True;
  tblList.AfterScroll := tblList_OnAfterScroll;
end;

procedure TQuickViewForm.EmptyTable();
begin
  tblList.AfterScroll := nil;
  tblList.Active := False;

  Grid.DataSource := nil;
  if Assigned(DS) then
    DS.DataSet := nil;

  tblList.Active := True;

  DS.DataSet := tblList;
  Grid.DataSource := DS;
  tblList.AfterScroll := tblList_OnAfterScroll;
end;

procedure TQuickViewForm.ReLoad();
var
  Id : string;
  Item: TLinkItem;
  i: Integer;
  Message: string;
begin
  Id := GetTableId();

  EmptyTable();

  if not Assigned(App.CurrentProject) then
    Exit;

  fQuickView.Load();

  tblList.DisableControls;
  try
    for i := 0 to fQuickView.List.Count - 1 do
    begin
      Item := fQuickView.List[i] as TLinkItem;
      AddToTable(Item);
    end;

    Message := Format('Quick View List loaded from: %s', [App.CurrentProject.QuickViewListFilePath]);
    LogBox.AppendLine(Message);
  finally
    tblList.EnableControls;
    tblList.First;
  end;

  GotToTableId(Id);
  SelectedLinkItemRowChanged();
end;

procedure TQuickViewForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
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

     if tblList.Locate('Id', PageId, []) then
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
    aekItemListChanged: ItemListChanged(TItemType(TBroadcasterIntegerArgs(Args).Value));     // (TItemType(TBroadcasterIntegerArgs(Args).Value));
    aekItemChanged: ItemChanged();             // (TBaseItem(Args.Data));
  end;
end;

procedure TQuickViewForm.DoClose(var CloseAction: TCloseAction);
begin
  if Assigned(tblList) then
  begin
    tblList.DisableControls();

    tblList.AfterScroll := nil;
    tblList.Active := False;

    Grid.DataSource := nil;
    if Assigned(DS) then
      DS.DataSet := nil;

    FreeAndNil(tblList);
  end;

  inherited DoClose(CloseAction);
end;

procedure TQuickViewForm.AddToTable(LinkItem: TLinkItem);
begin
 tblList.Append();
 tblList.FieldByName('Id').AsString := LinkItem.Id;
 tblList.FieldByName('Type').AsString := ItemTypeToString(LinkItem.ItemType);
 tblList.FieldByName('Place').AsString := LinkPlaceToString(LinkItem.Place);
 tblList.FieldByName('Name').AsString := LinkItem.Title;
 tblList.Post();
end;

function TQuickViewForm.GetTableId(): string;
begin
  Result := '';
  if Assigned(tblList) and (not tblList.IsEmpty) then
    Result := tblList.FieldByName('Id').AsString;
end;

function TQuickViewForm.GetItem(): TLinkItem;
var
  Id : string;
begin
  Result := nil;
  if not Assigned(App.CurrentProject) then
    Exit;

  Id := GetTableId();
  if Id <> '' then
    Result := fQuickView.FindById(Id);
end;

procedure TQuickViewForm.GotToTableId(const Id: string);
begin
  if (Id <> '') and Assigned(tblList) and (not tblList.IsEmpty)  then
    tblList.Locate('Id', Id, []);
end;

procedure TQuickViewForm.SaveList();
var
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  fQuickView.Save();
  Message := Format('Quick View List saved to: %s', [App.CurrentProject.QuickViewListFilePath]);
  LogBox.AppendLine(Message);
end;

procedure TQuickViewForm.AddToQuickView(LinkItem: TLinkItem);
var
  i : Integer;
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  // check if it is already in quick view
  for i := 0 to fQuickView.List.Count - 1 do
      if LinkItem.Item.Id = fQuickView.List[i].Item.Id then
      begin
        Message := Format('Item is already in Quick View: %s', [LinkItem.Title]);
        LogBox.AppendLine(Message);
        Exit;
      end;

  LinkItem.Collection := fQuickView.List;
  AddToTable(LinkItem);

  SaveList();

  Message := Format('Item is added to Quick View: %s', [LinkItem.Title]);
  LogBox.AppendLine(Message);

  SelectedLinkItemRowChanged();
end;

procedure TQuickViewForm.SelectedLinkItemRowChanged();
var
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  LinkItem := GetItem();
  if Assigned(LinkItem) then
  begin
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frmText.TextEditor);
  end else begin
    pnlTitle.Caption := 'No selection';
    frmText.EditorText := '';
  end;

end;

procedure TQuickViewForm.ShowLinkItemPage();
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

procedure TQuickViewForm.RemoveLinkItem();
var
  LinkItem: TLinkItem;

begin
  if not Assigned(App.CurrentProject) then
    Exit;

  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  fQuickView.List.Delete(LinkItem.Index);

  SaveList();
  ReLoad();

end;

procedure TQuickViewForm.RemoveAllLinkItems();
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if fQuickView.List.Count = 0 then
    Exit;

  if not App.QuestionBox('Are you sure you want to remove all items from Quick View?') then
    Exit;

  fQuickView.ClearAndSave();
end;

procedure TQuickViewForm.ShowItemInListPage();
var
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;
  if fQuickView.List.Count = 0 then
    Exit;

  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  App.ShowItemInListPage(LinkItem);

end;

procedure TQuickViewForm.MoveRow(Up: Boolean);
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

  Id := GetTableId();
  LinkItem := GetItem();
  if not Assigned(LinkItem) then
    Exit;

  if LinkItem.Move(Up) then
  begin
    ReLoad();
    tblList.Locate('Id', Id, []);
  end;

end;



procedure TQuickViewForm.PrepareToolBar();
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

procedure TQuickViewForm.AnyClick(Sender: TObject);
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

procedure TQuickViewForm.tblList_OnAfterScroll(Dataset: TDataset);
begin
  SelectedLinkItemRowChanged();
end;

procedure TQuickViewForm.Grid_OnDoubleClick(Sender: TObject);
begin
  ShowLinkItemPage();
end;




end.

