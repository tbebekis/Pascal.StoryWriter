unit f_TagListForm;

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
  , StdCtrls
  , Contnrs
  , Menus
  , DB
  , DBCtrls
  , DBGrids
  , f_PageForm
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities
  , o_MarkDownPreview
  ;

type

  { TTagListForm }

  TTagListForm = class(TPageForm)
    Grid: TDBGrid;
    lboAliases: TListBox;
    lboTagList: TListBox;
    lboTags: TListBox;
    Pager: TPageControl;
    pnlBottom: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    Splitter2: TSplitter;
    tabAliases: TTabSheet;
    tabTags: TTabSheet;
    tabText: TTabSheet;
    ToolBar: TToolBar;
  private
    tblComponents : TMemTable;
    DS: TDatasource;

     MarkdownPreview: TMarkdownPreview;

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
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
  end;


implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_Consts
  ,o_App
  ,f_ComponentForm
  ,f_QuickViewForm
  ;


{ TTagListForm }

constructor TTagListForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  MarkdownPreview := TMarkdownPreview.Create(Self);
  MarkdownPreview.Parent := tabText;
end;

destructor TTagListForm.Destroy();
begin
  inherited Destroy();
end;

procedure TTagListForm.FormInitialize;
begin
  ParentTabPage.Caption := 'Tags';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  PrepareToolBar();

  Pager.ActivePage := tabText;

  Grid.OnDblClick := GridOnDblClick;
  lboTagList.OnSelectionChange := lboTagList_OnSelectionChange;

  //Sys.RunOnce(1000 * 5, Reload);
  ReLoad();
end;

procedure TTagListForm.FormInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
  lboTagList.Width := (pnlTop.ClientWidth - Splitter2.Width) div 2;
end;

procedure TTagListForm.ReLoad();
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

procedure TTagListForm.ReLoadTagList();
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

procedure TTagListForm.ReloadComponents();
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

procedure TTagListForm.SelectedTagChanged();
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

procedure TTagListForm.SelectedComponentChanged();
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
  MarkdownPreview.SetMarkdownText('');

  if tblComponents.IsEmpty then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  pnlTitle.Caption := Comp.Title;
  MarkdownPreview.SetMarkdownText(Comp.Text);

  lboTags.Items.AddStrings(Comp.TagList);
  lboAliases.Items.AddStrings(Comp.AliasList);
end;

procedure TTagListForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekTagListChanged: if Args.Sender <> Self then ReLoad();
    aekComponentListChanged: if Args.Sender <> Self then ReLoad();
  end;
end;

procedure TTagListForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnDeleteTag := AddButton(ToolBar, 'table_delete', 'Remove Tag', AnyClick);
    btnEditComponentText := AddButton(ToolBar, 'page_edit', 'Edit Component Text', AnyClick);
    btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected Component to Quick View List', AnyClick);
  finally
    ToolBar.Parent := P;
  end;


end;

procedure TTagListForm.DeleteTag();
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
    App.PerformTagListChanged(Self);
    LogBox.AppendLine(Format('Tag ''%s'' deleted.', [sTag]));
  end;

end;

procedure TTagListForm.EditComponentText();
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

  App.ContentPagerHandler.ShowPage(TComponentForm, Comp.Id, Comp);
end;

procedure TTagListForm.AddToQuickView();
var
  Id : string;
  Comp: TSWComponent;
  LinkItem : TLinkItem;
  TabPage : TTabSheet;
  QuickView: TQuickViewForm;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  TabPage :=  App.SideBarPagerHandler.ShowPage(TQuickViewForm, TQuickViewForm.ClassName, nil);
  if (not Assigned(TabPage)) or (TabPage.Tag = 0) then
    Exit;

  QuickView := TQuickViewForm(TabPage.Tag);

  LinkItem := TLinkItem.Create(nil);
  LinkItem.Item := Comp;
  LinkItem.ItemType := itComponent;
  LinkItem.Place := lpTitle;
  LinkItem.Title := Comp.Title;

  QuickView.AddToQuickView(LinkItem);
end;

procedure TTagListForm.AnyClick(Sender: TObject);
begin
  if btnDeleteTag = Sender then
     DeleteTag()
  else if btnEditComponentText = Sender then
    EditComponentText()
  else if btnAddToQuickView = Sender then
    AddToQuickView();
end;

procedure TTagListForm.GridOnDblClick(Sender: TObject);
begin
  EditComponentText();
end;

procedure TTagListForm.lboTagList_OnSelectionChange(Sender: TObject; User: boolean);
begin
  SelectedTagChanged();
end;

procedure TTagListForm.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;

end.

