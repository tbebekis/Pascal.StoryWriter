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
  , Tripous.Forms.FramePage
  , Tripous.MemTable
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

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnComponentListChanged(Sender: TObject);
    procedure AppOnTagListChanged(Sender: TObject);
    procedure AppOnItemChanged(Sender: TObject; Item: TBaseItem);

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
  public
    constructor Create(AOwner: TComponent); override;

    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
  end;

implementation

{$R *.lfm}

uses
  Tripous.Logs
  ,o_App
  ;

{ TfrCategoryList }

constructor TfrCategoryList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;

  App.OnComponentListChanged := AppOnComponentListChanged;
  App.OnTagListChanged := AppOnTagListChanged;
  App.OnItemChanged := AppOnItemChanged;

  Grid.OnDblClick := GridOnDblClick;
  lboCategoryList.OnSelectionChange := lboCategoryList_OnSelectionChange;
end;

procedure TfrCategoryList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Categories';

  ReLoad();
end;

procedure TfrCategoryList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
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

  if lboCategoryList.ItemIndex > 0 then
    lboCategoryList.ItemIndex := 0;

  if SelectedName <> '' then
  begin
    Index := lboCategoryList.Items.IndexOf(SelectedName);
    if Index >= 0 then
      lboCategoryList.ItemIndex := Index;
  end;
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
(*
List<string> NamesList = App.CurrentProject.GetCategoryList();
lboCategoryList.BeginUpdate();
lboCategoryList.Items.Clear();
lboCategoryList.Items.AddRange(NamesList.ToArray());
lboCategoryList.EndUpdate();

SelectedCategoryChanged();
*)
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

procedure TfrCategoryList.lboCategoryList_OnSelectionChange(Sender: TObject; User: boolean);
begin
  SelectedCategoryChanged();
end;

procedure TfrCategoryList.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
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

procedure TfrCategoryList.AnyClick(Sender: TObject);
begin

end;

procedure TfrCategoryList.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrCategoryList.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrCategoryList.AppOnComponentListChanged(Sender: TObject);
begin

end;

procedure TfrCategoryList.AppOnTagListChanged(Sender: TObject);
begin

end;

procedure TfrCategoryList.AppOnItemChanged(Sender: TObject; Item: TBaseItem);
begin

end;

procedure TfrCategoryList.GridOnDblClick(Sender: TObject);
begin

end;



procedure TfrCategoryList.PrepareToolBar();
begin

end;

procedure TfrCategoryList.DeleteCategory();
begin

end;

procedure TfrCategoryList.EditComponentText();
begin

end;

procedure TfrCategoryList.AddToQuickView();
begin

end;






end.

