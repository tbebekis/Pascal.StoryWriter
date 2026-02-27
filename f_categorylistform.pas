unit f_CategoryListForm;

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

  { TCategoryListForm }

  TCategoryListForm = class(TPageForm)
    Grid: TDBGrid;
    lboAliases: TListBox;
    lboCategoryList: TListBox;
    lboTags: TListBox;
    Pager: TPageControl;
    pnlBottom: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    Splitter2: TSplitter;
    tabText: TTabSheet;
    tabTags: TTabSheet;
    tabAliases: TTabSheet;
    ToolBar: TToolBar;
  private
    tblComponents : TMemTable;
    DS: TDatasource;

    MarkdownPreview: TMarkdownPreview;

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

{ TCategoryListForm }

constructor TCategoryListForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  MarkdownPreview := TMarkdownPreview.Create(Self);
  MarkdownPreview.Parent := tabText;
end;

destructor TCategoryListForm.Destroy();
begin
  inherited Destroy();
end;

procedure TCategoryListForm.FormInitialize();
begin
  ParentTabPage.Caption := 'Categories';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  PrepareToolBar();

  Pager.ActivePage := tabText;

  Grid.OnDblClick := GridOnDblClick;
  lboCategoryList.OnSelectionChange := lboCategoryList_OnSelectionChange;

  //Sys.RunOnce(1000 * 5, Reload);
  ReLoad();
end;

procedure TCategoryListForm.FormInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
  lboCategoryList.Width := (pnlTop.ClientWidth - Splitter2.Width) div 2;
end;

procedure TCategoryListForm.ReLoad();
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

procedure TCategoryListForm.ReLoadCategoryList();
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

procedure TCategoryListForm.ReloadComponents();
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

procedure TCategoryListForm.SelectedCategoryChanged();
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

procedure TCategoryListForm.SelectedComponentChanged();
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

procedure TCategoryListForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekTagListChanged: if Args.Sender <> Self then ReLoad();
    aekComponentListChanged: if Args.Sender <> Self then ReLoad();
  end;

end;


procedure TCategoryListForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnDeleteCategory := AddButton(ToolBar, 'table_delete', 'Remove Category', AnyClick);
    btnEditComponentText := AddButton(ToolBar, 'page_edit', 'Edit Component Text', AnyClick);
    btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected Component to Quick View List', AnyClick);
  finally
    ToolBar.Parent := P;
  end;


end;

procedure TCategoryListForm.DeleteCategory();
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
      App.PerformCategoryListChanged(Self);
      LogBox.AppendLine(Format('Category ''%s'' deleted.', [Category]));
    end;

  end;
end;

procedure TCategoryListForm.EditComponentText();
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

procedure TCategoryListForm.AddToQuickView();
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

procedure TCategoryListForm.AnyClick(Sender: TObject);
begin
  if btnDeleteCategory = Sender then
     DeleteCategory()
  else if btnEditComponentText = Sender then
    EditComponentText()
  else if btnAddToQuickView = Sender then
    AddToQuickView();
end;

procedure TCategoryListForm.GridOnDblClick(Sender: TObject);
begin
  EditComponentText();
end;

procedure TCategoryListForm.lboCategoryList_OnSelectionChange(Sender: TObject; User: boolean);
begin
  SelectedCategoryChanged();
end;

procedure TCategoryListForm.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;





end.

