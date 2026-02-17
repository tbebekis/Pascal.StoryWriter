unit fr_CategoryList;

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
  , DB
  , DBCtrls
  , DBGrids
  , fr_FramePage
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities, fr_MarkdownPreview
  ;

type

  { TfrCategoryList }

  TfrCategoryList = class(TFramePage)
    Grid: TDBGrid;
    lboCategoryList: TListBox;
    lboTags: TListBox;
    lboAliases: TListBox;
    Preview: TMarkdownPreview;
    Pager: TPageControl;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    pnlBottom: TPanel;
    Splitter: TSplitter;
    Splitter2: TSplitter;
    tabText: TTabSheet;
    tabTags: TTabSheet;
    tabAliases: TTabSheet;
    ToolBar: TToolBar;
  private
    tblComponents : TMemTable;
    DS: TDatasource;

    btnDeleteCategory : TToolButton;
    btnEditComponentText : TToolButton;
    btnAddToQuickView : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure GridOnDblClick(Sender: TObject);
    procedure lboCategoryList_OnSelectionChange(Sender: TObject; User: boolean);
    procedure tblComponents_OnAfterScroll(Dataset: TDataset);

    procedure PrepareToolBar();

    procedure DeleteCategory();
    procedure EditComponentText();
    procedure AddToQuickView();

    procedure ReLoad();
    procedure ReLoadCategoryList();
    procedure ReloadComponents();

    procedure SelectedCategoryChanged();
    procedure SelectedComponentChanged();
  protected
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
  end;

implementation

{$R *.lfm}

uses
  Tripous.Logs
  ,o_Consts
  ,o_App
  ,fr_Component
  ,fr_QuickView
  ;

{ TfrCategoryList }

procedure TfrCategoryList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Categories';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  PrepareToolBar();

  Pager.ActivePage := tabText;

  Grid.OnDblClick := GridOnDblClick;
  lboCategoryList.OnSelectionChange := lboCategoryList_OnSelectionChange;

  ReLoad();
end;

procedure TfrCategoryList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
  lboCategoryList.Width := (pnlTop.ClientWidth - Splitter2.Width) div 2;
end;

procedure TfrCategoryList.ReLoad();
var
  SelectedName : string;
  Index : Integer;
begin
  SelectedName := '';
  if lboCategoryList.ItemIndex >= 0 then
    SelectedName := lboCategoryList.Items[lboCategoryList.ItemIndex];

  ReLoadCategoryList();
  ReloadComponents();

  if (lboCategoryList.ItemIndex = -1) and (lboCategoryList.Count > 0) then
    lboCategoryList.ItemIndex := 0;

  if SelectedName <> '' then
  begin
    Index := lboCategoryList.Items.IndexOf(SelectedName);
    if Index >= 0 then
      lboCategoryList.ItemIndex := Index;
  end;

  SelectedComponentChanged();
end;

procedure TfrCategoryList.ReLoadCategoryList();
var
  List: TStrings;
begin
  List := App.CurrentProject.GetCategoryList();
  try
    lboCategoryList.Items.Clear();
    lboCategoryList.Items.AddStrings(List);
  finally
    List.Free();
  end;

  SelectedCategoryChanged();
end;

procedure TfrCategoryList.ReloadComponents();
var
  i : Integer;
  Item : TSWComponent;
  List: TObjectList;
begin
  if not Assigned(tblComponents) then
  begin
    tblComponents := TMemTable.Create(Self);
    tblComponents.FieldDefs.Add('Id', ftString, 100);
    tblComponents.FieldDefs.Add('Title', ftString, 100);
    tblComponents.FieldDefs.Add('Category', ftString, 100);
    tblComponents.FieldDefs.Add('TagList', ftString, 100);
    tblComponents.CreateDataset;

    DS := TDataSource.Create(Self);
    DS.DataSet := tblComponents;

    App.InitializeReadOnly(Grid);
    App.AddColumn(Grid, 'Title', 'Component');
    Grid.DataSource := DS;

    App.AdjustGridColumns(Grid);

    tblComponents.Active := True;
    tblComponents.AfterScroll := tblComponents_OnAfterScroll;
  end;

  if Assigned(App.CurrentProject) then
  begin
    List := App.CurrentProject.GetComponentList();
    tblComponents.DisableControls();
    try
      tblComponents.EmptyDataSet();

      for i := 0 to List.Count - 1 do
      begin
        Item := List[i] as TSWComponent;
        tblComponents.Append();
        tblComponents.FieldByName('Id').AsString := Item.Id;
        tblComponents.FieldByName('Title').AsString := Item.Title;
        tblComponents.FieldByName('Category').AsString := Item.Category;
        tblComponents.FieldByName('TagList').AsString := Item.GetTagsAsLine();
        tblComponents.Post();
      end;
    finally
      tblComponents.EnableControls();
      List.Free();
    end;
  end;


end;

procedure TfrCategoryList.SelectedCategoryChanged();
var
  SelectedName : string;
  S : string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  SelectedName := '';
  if lboCategoryList.ItemIndex >= 0 then
    SelectedName := lboCategoryList.Items[lboCategoryList.ItemIndex];

  S := '$_NOT_EXISTED_COMPONENT_$';
  if SelectedName <> '' then
    S := SelectedName;

  S := Format('Category = ''%s''', [S]);
  tblComponents.Filtered := False;
  tblComponents.Filter := S;
  tblComponents.Filtered := True;

  SelectedComponentChanged();
end;

procedure TfrCategoryList.SelectedComponentChanged();
var
  Id : string;
  Comp: TSWComponent;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  pnlTitle.Caption := 'No selection';
  lboTags.Items.Clear();
  lboAliases.Items.Clear();
  Preview.SetMarkdownText('');

  if tblComponents.IsEmpty then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  pnlTitle.Caption := Comp.Title;
  Preview.SetMarkdownText(Comp.Text);

  lboTags.Items.AddStrings(Comp.TagList);
  lboAliases.Items.AddStrings(Comp.AliasList);
end;

procedure TfrCategoryList.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekProjectOpened : ReLoad();
    aekProjectClosed : SelectedComponentChanged();
    //aekItemListChanged: AppOnItemListChanged(Args);     // (TItemType(TBroadcasterIntegerArgs(Args).Value));
    //aekItemChanged: AppOnItemChanged(Args);             // (TBaseItem(Args.Data));
    //aekSearchTermIsSet: AppOnSearchTermIsSet(Args);     // (string(TBroadcasterTextArgs(Args).Value));
    //aekCategoryListChanged: AppOnCategoryListChanged(Args);
    aekTagListChanged: if Args.Sender <> Self then ReLoad();
    aekComponentListChanged: if Args.Sender <> Self then ReLoad();
    //aekProjectMetricsChanged: AppOnProjectMetricsChanged(Args);
  end;

end;


procedure TfrCategoryList.PrepareToolBar();
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  btnDeleteCategory := AddButton(ToolBar, 'table_delete', 'Remove Category', AnyClick);
  btnEditComponentText := AddButton(ToolBar, 'page_edit', 'Edit Component Text', AnyClick);
  btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected Component to Quick View List', AnyClick);
end;

procedure TfrCategoryList.DeleteCategory();
var
  Flag: Boolean;
  Category: string;
  Comp: TCollectionItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  if lboCategoryList.ItemIndex >= 0 then
  begin
    Flag := False;
    Category := lboCategoryList.Items[lboCategoryList.ItemIndex];

    if not App.QuestionBox(Format('Delete Category ''%s''?', [Category])) then
      Exit;

    for Comp in App.CurrentProject.ComponentList do
    begin
      if AnsiSameText(Category, TSWComponent(Comp).Category) then
      begin
        lboCategoryList.Items.Delete(lboCategoryList.ItemIndex);
        Flag := True;
        TSWComponent(Comp).Category := 'No Category';
      end;
    end;

    if Flag then
    begin
      App.CurrentProject.SaveJson;
      ReLoad();
      Broadcaster.Broadcast(SCategoryListChanged, Self);
      LogBox.AppendLine(Format('Category ''%s'' deleted.', [Category]));
    end;

  end;
end;

procedure TfrCategoryList.EditComponentText();
var
  Id: string;
  Comp: TSWComponent;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  App.ContentPagerHandler.ShowPage(TfrComponent, Comp.Id, Comp);

end;

procedure TfrCategoryList.AddToQuickView();
var
  Id : string;
  Comp: TSWComponent;
  LinkItem : TLinkItem;
  TabPage : TTabSheet;
  QuickView: TfrQuickView;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  TabPage :=  App.SideBarPagerHandler.ShowPage(TfrQuickView, TfrQuickView.ClassName, nil);
  if (not Assigned(TabPage)) or (TabPage.Tag = 0) then
    Exit;

  QuickView := TfrQuickView(TabPage.Tag);

  LinkItem := TLinkItem.Create(nil);
  LinkItem.Item := Comp;
  LinkItem.ItemType := itComponent;
  LinkItem.Place := lpTitle;
  LinkItem.Title := Comp.Title;

  QuickView.AddToQuickView(LinkItem);

end;

procedure TfrCategoryList.AnyClick(Sender: TObject);
begin
  if btnDeleteCategory = Sender then
     DeleteCategory()
  else if btnEditComponentText = Sender then
    EditComponentText()
  else if btnAddToQuickView = Sender then
    AddToQuickView();
end;

procedure TfrCategoryList.GridOnDblClick(Sender: TObject);
begin
  EditComponentText();
end;

procedure TfrCategoryList.lboCategoryList_OnSelectionChange(Sender: TObject; User: boolean);
begin
  SelectedCategoryChanged();
end;

procedure TfrCategoryList.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;




end.

