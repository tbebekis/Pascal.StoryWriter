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
  , StdCtrls
  , Contnrs
  , Menus
  , LCLType
  , LCLIntf
  , DB
  , DBCtrls
  , DBGrids
  , Tripous.Forms.FramePage
  , Tripous.MemTable
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
    LinkItemList: TLinkItemList;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnItemChanged(Sender: TObject; Item: TBaseItem);
    procedure AppOnItemListChanged(Sender: TObject; ItemType: TItemType);

    procedure tblList_OnAfterScroll(Dataset: TDataset);

    procedure LoadList();
    procedure SaveList();

    procedure ShowLinkItemPage();
    procedure RemoveLinkItem();
    procedure RemoveAllLinkItems();
    procedure ShowItemInListPage();
    procedure MoveRow(Up: Boolean);

    procedure ClearResults();
    procedure SelectedLinkItemRowChanged();

    procedure AddToTable(LinkItem: TLinkItem);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    procedure AddToQuickView(LinkItem: TLinkItem);
  end;

implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_App
  ;

{ TfrQuickView }


constructor TfrQuickView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  LinkItemList := TLinkItemList.Create(nil);
end;

destructor TfrQuickView.Destroy();
begin
  if Assigned(LinkItemList) then
  begin

    FreeAndNil(LinkItemList);
  end;
  inherited Destroy();
end;

procedure TfrQuickView.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Quick View';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  frText.ToolBarVisible := False;
  frText.Editor.ReadOnly := True;

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;
  App.OnItemChanged := AppOnItemChanged;
  App.OnItemChanged := AppOnItemChanged;

  LoadList();
end;

procedure TfrQuickView.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
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

procedure TfrQuickView.LoadList();
var
  Item: TLinkItem;
  ListCount, i: Integer;
  FilePath: string;
  ListToDelete: TObjectList;
  Message: string;
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

    App.AddColumn(Grid, 'Type', 'Type');
    App.AddColumn(Grid, 'Place', 'Place');
    App.AddColumn(Grid, 'Name', 'Name');
    Grid.DataSource := DS;

    App.InitializeReadOnly(Grid);
    App.AdjustGridColumns(Grid);

    tblList.Active := True;
    tblList.AfterScroll := tblList_OnAfterScroll;
  end;

  if not Assigned(App.CurrentProject) then
    Exit;

  FilePath := App.CurrentProject.QuickViewListFilePath;

  if not FileExists(FilePath) then
    Exit;

  ListToDelete := TObjectList.Create(False);
  try
    LinkItemList.Clear();
    Json.LoadFromFile(FilePath, LinkItemList);
    ListCount := LinkItemList.Count;

    for i := 0 to LinkItemList.Count - 1 do
    begin
      LinkItemList[i].LoadItem();
      if not Assigned(LinkItemList[i].Item) then
        ListToDelete.Add(LinkItemList[i]);
    end;

    for i := 0 to ListToDelete.Count - 1 do
      LinkItemList[i].Free();

    // if needs saving, save the list
    if ListCount <> LinkItemList.Count then
      Json.SaveToFile(App.CurrentProject.QuickViewListFilePath, LinkItemList);

    tblList.DisableControls;
    try
      tblList.EmptyDataSet;
      for i := 0 to LinkItemList.Count - 1 do
      begin
        Item := LinkItemList[i] as TLinkItem;
        AddToTable(Item);
      end;

      Message := Format('Quick View List loaded from: %s', [App.CurrentProject.QuickViewListFilePath]);
      LogBox.AppendLine(Message);
    finally
      tblList.EnableControls;
    end;

  finally
    ListToDelete.Free();
  end;


  SelectedLinkItemRowChanged();

end;

procedure TfrQuickView.SaveList();
var
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Json.SaveToFile(App.CurrentProject.QuickViewListFilePath, LinkItemList);
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
  for i := 0 to LinkItemList.Count - 1 do
      if LinkItem.Item.Id = LinkItemList[i].Item.Id then
      begin
        Message := Format('Item is already in Quick View: %s', [LinkItem.Title]);
        LogBox.AppendLine(Message);
        Exit;
      end;

  LinkItem.Collection := LinkItemList;
  AddToTable(LinkItem);

  SaveList();

  Message := Format('Item is added to Quick View: %s', [LinkItem.Title]);
  LogBox.AppendLine(Message);

  SelectedLinkItemRowChanged();
end;

procedure TfrQuickView.SelectedLinkItemRowChanged();
var
  LinkItem: TLinkItem;
  Id: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblList) then
    Exit;

  Id := tblList.FieldByName('Id').AsString;
  LinkItem := LinkItemList.FindById(Id);
  if Assigned(LinkItem) then
  begin
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frText.Editor);
    Application.ProcessMessages();
  end else begin
    pnlTitle.Caption := 'No selection';
    frText.Editor.Clear();
  end;

  (*
  if Assigned(tv.Selected) and Assigned(tv.Selected.Data) then
  begin
    LinkItem := TLinkItem(tv.Selected.Data);
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frText.Editor);
    Application.ProcessMessages();
  end;


lblItemTitle.Text = "No selection";
ucText.Clear();

DataRow Row = bsList.CurrentDataRow();
if (Row != null)
{
    LinkItem LinkItem = Row["OBJECT"] as LinkItem;
    App.UpdateLinkItemUi(LinkItem, lblItemTitle, ucText);
}
*)
end;

procedure TfrQuickView.AnyClick(Sender: TObject);
begin

end;

procedure TfrQuickView.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrQuickView.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrQuickView.AppOnItemChanged(Sender: TObject; Item: TBaseItem);
begin

end;

procedure TfrQuickView.AppOnItemListChanged(Sender: TObject; ItemType: TItemType);
begin

end;

procedure TfrQuickView.tblList_OnAfterScroll(Dataset: TDataset);
begin
  SelectedLinkItemRowChanged();
end;

procedure TfrQuickView.ShowLinkItemPage();
begin

end;

procedure TfrQuickView.RemoveLinkItem();
begin

end;

procedure TfrQuickView.RemoveAllLinkItems();
begin

end;

procedure TfrQuickView.ShowItemInListPage();
begin

end;

procedure TfrQuickView.MoveRow(Up: Boolean);
begin

end;

procedure TfrQuickView.ClearResults();
begin

end;












end.

