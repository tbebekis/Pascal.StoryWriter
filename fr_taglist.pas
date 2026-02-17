unit fr_TagList;

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

  { TfrTagList }

  TfrTagList = class(TFramePage)
    Grid: TDBGrid;
    lboAliases: TListBox;
    lboTagList: TListBox;
    lboTags: TListBox;
    Pager: TPageControl;
    pnlBottom: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Preview: TMarkdownPreview;
    Splitter: TSplitter;
    Splitter2: TSplitter;
    tabAliases: TTabSheet;
    tabTags: TTabSheet;
    tabText: TTabSheet;
    ToolBar: TToolBar;
  private
    tblComponents : TMemTable;
    DS: TDatasource;

    btnDeleteTag : TToolButton;
    btnEditComponentText : TToolButton;
    btnAddToQuickView : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure GridOnDblClick(Sender: TObject);
    procedure lboTagList_OnSelectionChange(Sender: TObject; User: boolean);
    procedure tblComponents_OnAfterScroll(Dataset: TDataset);

    procedure PrepareToolBar();

    procedure DeleteTag();
    procedure EditComponentText();
    procedure AddToQuickView();

    procedure ReLoad();
    procedure ReLoadTagList();
    procedure ReloadComponents();

    procedure SelectedTagChanged();
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

{ TfrTagList }

procedure TfrTagList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Tags';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  PrepareToolBar();

  Pager.ActivePage := tabText;

  Grid.OnDblClick := GridOnDblClick;
  lboTagList.OnSelectionChange := lboTagList_OnSelectionChange;

  ReLoad();
end;

procedure TfrTagList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
  lboTagList.Width := (pnlTop.ClientWidth - Splitter2.Width) div 2;
end;

procedure TfrTagList.ReLoad();
var
  SelectedName : string;
  Index : Integer;
begin
  SelectedName := '';
  if lboTagList.ItemIndex >= 0 then
    SelectedName := lboTagList.Items[lboTagList.ItemIndex];

  ReLoadTagList();
  ReloadComponents();

  if (lboTagList.ItemIndex = -1) and (lboTagList.Count > 0) then
    lboTagList.ItemIndex := 0;

  if SelectedName <> '' then
  begin
    Index := lboTagList.Items.IndexOf(SelectedName);
    if Index >= 0 then
      lboTagList.ItemIndex := Index;
  end;

  SelectedComponentChanged();

end;

procedure TfrTagList.ReLoadTagList();
var
  List: TStrings;
begin
  List := App.CurrentProject.GetTagList();
  try
    lboTagList.Items.Clear();
    lboTagList.Items.AddStrings(List);
  finally
    List.Free();
  end;

  SelectedTagChanged();
end;

procedure TfrTagList.ReloadComponents();
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
    App.AddColumn(Grid, 'Category', 'Category');
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

procedure TfrTagList.SelectedTagChanged();
var
  SelectedName : string;
  S : string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  SelectedName := '';
  if lboTagList.ItemIndex >= 0 then
    SelectedName := lboTagList.Items[lboTagList.ItemIndex];

  S := '$_NOT_EXISTED_COMPONENT_$';
  if SelectedName <> '' then
    S := SelectedName;

  //S := Format('TagList LIKE ''%s''', [S]);
  S := Format('TagList LIKE ''%%%s%%''', [S]);
  tblComponents.Filtered := False;
  tblComponents.Filter := S;
  tblComponents.Filtered := True;

  SelectedComponentChanged();
end;

procedure TfrTagList.SelectedComponentChanged();
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

procedure TfrTagList.OnBroadcasterEvent(Args: TBroadcasterArgs);
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

procedure TfrTagList.PrepareToolBar();
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  btnDeleteTag := AddButton(ToolBar, 'table_delete', 'Remove Tag', AnyClick);
  btnEditComponentText := AddButton(ToolBar, 'page_edit', 'Edit Component Text', AnyClick);
  btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected Component to Quick View List', AnyClick);
end;

procedure TfrTagList.DeleteTag();
var
  sTag: string;
  Comp: TCollectionItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  if lboTagList.ItemIndex >= 0 then
  begin
    sTag := lboTagList.Items[lboTagList.ItemIndex];

    if not App.QuestionBox(Format('Delete Tag ''%s''?', [sTag])) then
      Exit;

    for Comp in App.CurrentProject.ComponentList do
    begin
      if TSWComponent(Comp).ContainsTag(sTag) then
        TSWComponent(Comp).RemoveTag(sTag);
    end;

    lboTagList.Items.Delete(lboTagList.ItemIndex);

    App.CurrentProject.SaveJson;
    ReLoad();
    Broadcaster.Broadcast(STagListChanged, Self);
    LogBox.AppendLine(Format('Tag ''%s'' deleted.', [sTag]));
  end;

end;

procedure TfrTagList.EditComponentText();
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

procedure TfrTagList.AddToQuickView();
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

procedure TfrTagList.AnyClick(Sender: TObject);
begin
  if btnDeleteTag = Sender then
     DeleteTag()
  else if btnEditComponentText = Sender then
    EditComponentText()
  else if btnAddToQuickView = Sender then
    AddToQuickView();
end;

procedure TfrTagList.GridOnDblClick(Sender: TObject);
begin
  EditComponentText();
end;

procedure TfrTagList.lboTagList_OnSelectionChange(Sender: TObject; User: boolean);
begin
  SelectedTagChanged();
end;

procedure TfrTagList.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;

end.

