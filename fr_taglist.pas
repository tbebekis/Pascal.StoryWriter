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
  , Tripous.Forms.FramePage
  , Tripous.MemTable
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
    tblTags : TMemTable;
    DS: TDatasource;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnComponentListChanged(Sender: TObject);
    procedure AppOnCategoryListChanged(Sender: TObject);
    procedure AppOnItemChanged(Sender: TObject; Item: TBaseItem);

    procedure GridOnDblClick(Sender: TObject);
    procedure lboTagList_OnSelectionChange(Sender: TObject; User: boolean);
    procedure tblTags_OnAfterScroll(Dataset: TDataset);

    procedure PrepareToolBar();

    procedure DeleteTag();
    procedure EditComponentText();
    procedure AddToQuickView();

    procedure ReLoad();
    procedure ReLoadTagList();
    procedure ReloadComponents();

    procedure SelectedTagChanged();
    procedure SelectedComponentChanged();
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
  end;

implementation

{$R *.lfm}

uses
  Tripous.Logs
  ,o_App
  ;

{ TfrTagList }

procedure TfrTagList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Tags';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  Pager.ActivePage := tabText;

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;

  App.OnComponentListChanged := AppOnComponentListChanged;
  App.OnCategoryListChanged := AppOnCategoryListChanged;
  App.OnItemChanged := AppOnItemChanged;

  Grid.OnDblClick := GridOnDblClick;
  lboTagList.OnSelectionChange := lboTagList_OnSelectionChange;

  ReLoad();
end;

procedure TfrTagList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
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
  if not Assigned(tblTags) then
  begin
    tblTags := TMemTable.Create(Self);
    tblTags.FieldDefs.Add('Id', ftString, 100);
    tblTags.FieldDefs.Add('Title', ftString, 100);
    tblTags.FieldDefs.Add('Category', ftString, 100);
    tblTags.FieldDefs.Add('TagList', ftString, 100);
    tblTags.CreateDataset;

    DS := TDataSource.Create(Self);
    DS.DataSet := tblTags;

    App.InitializeReadOnly(Grid);
    App.AddColumn(Grid, 'Category', 'Category');
    App.AddColumn(Grid, 'Title', 'Component');
    Grid.DataSource := DS;

    App.AdjustGridColumns(Grid);

    tblTags.Active := True;
    tblTags.AfterScroll := tblTags_OnAfterScroll;
  end;

  if Assigned(App.CurrentProject) then
  begin
    List := App.CurrentProject.GetComponentList();
    tblTags.DisableControls();
    try
      tblTags.EmptyDataSet();

      for i := 0 to List.Count - 1 do
      begin
        Item := List[i] as TSWComponent;
        tblTags.Append();
        tblTags.FieldByName('Id').AsString := Item.Id;
        tblTags.FieldByName('Title').AsString := Item.Title;
        tblTags.FieldByName('Category').AsString := Item.Category;
        tblTags.FieldByName('TagList').AsString := Item.GetTagsAsLine();
        tblTags.Post();
      end;
    finally
      tblTags.EnableControls();
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

  if not Assigned(tblTags) then
    Exit;

  SelectedName := '';
  if lboTagList.ItemIndex >= 0 then
    SelectedName := lboTagList.Items[lboTagList.ItemIndex];

  S := '$_NOT_EXISTED_COMPONENT_$';
  if SelectedName <> '' then
    S := SelectedName;

  //S := Format('TagList LIKE ''%s''', [S]);
  S := Format('TagList LIKE ''%%%s%%''', [S]);
  tblTags.Filtered := False;
  tblTags.Filter := S;
  tblTags.Filtered := True;

  SelectedComponentChanged();
end;

procedure TfrTagList.SelectedComponentChanged();
var
  Id : string;
  Comp: TSWComponent;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblTags) then
    Exit;

  pnlTitle.Caption := 'No selection';
  lboTags.Items.Clear();
  lboAliases.Items.Clear();
  Preview.SetMarkdownText('');

  if tblTags.IsEmpty then
    Exit;

  Id := tblTags.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  pnlTitle.Caption := Comp.Title;
  Preview.SetMarkdownText(Comp.Text);

  lboTags.Items.AddStrings(Comp.TagList);
  lboAliases.Items.AddStrings(Comp.AliasList);
end;

procedure TfrTagList.PrepareToolBar();
begin

end;

procedure TfrTagList.DeleteTag();
begin

end;

procedure TfrTagList.EditComponentText();
begin

end;

procedure TfrTagList.AddToQuickView();
begin

end;

procedure TfrTagList.AnyClick(Sender: TObject);
begin

end;

procedure TfrTagList.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrTagList.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrTagList.AppOnComponentListChanged(Sender: TObject);
begin

end;

procedure TfrTagList.AppOnCategoryListChanged(Sender: TObject);
begin

end;

procedure TfrTagList.AppOnItemChanged(Sender: TObject; Item: TBaseItem);
begin

end;

procedure TfrTagList.GridOnDblClick(Sender: TObject);
begin

end;

procedure TfrTagList.lboTagList_OnSelectionChange(Sender: TObject; User: boolean);
begin
  SelectedTagChanged();
end;

procedure TfrTagList.tblTags_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;

end.

