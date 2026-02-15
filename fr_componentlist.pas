unit fr_ComponentList;

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
  , DB
  , DBCtrls
  , DBGrids
  , Tripous.Forms.FramePage
  , Tripous.MemTable
  , o_Entities, fr_MarkdownPreview
  ;

type

  { TfrComponentList }

  TfrComponentList = class(TFramePage)
    edtFilter: TEdit;
    Grid: TDBGrid;
    Label1: TLabel;
    lboAliases: TListBox;
    lboTags: TListBox;
    Pager: TPageControl;
    pnlFilter: TPanel;
    pnlBottom: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Preview: TMarkdownPreview;
    Splitter: TSplitter;
    tabAliases: TTabSheet;
    tabTags: TTabSheet;
    tabText: TTabSheet;
    ToolBar: TToolBar;
  private
    tblComponents: TMemTable;
    DS: TDatasource;

    btnAddComponent : TToolButton;
    btnEditComponent : TToolButton;
    btnDeleteComponent : TToolButton;
    btnEditText : TToolButton;
    btnAddToQuickView : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnComponentListChanged(Sender: TObject);
    procedure AppOnCategoryListChanged(Sender: TObject);
    procedure AppOnItemChanged(Sender: TObject; Item: TBaseItem);

    procedure GridOnDblClick(Sender: TObject);
    procedure GridOnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterOnTextChanged(Sender: TObject);
    procedure tblComponents_OnAfterScroll(Dataset: TDataset);

    procedure PrepareToolBar();

    procedure AddComponent();
    procedure DeleteComponent();
    procedure EditComponent();
    procedure EditComponentText();
    procedure AddToQuickView();

    procedure ReLoad();
    procedure SelectedComponentChanged();
    procedure FilterChanged();
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
  end;

implementation

{$R *.lfm}

uses
  Tripous.Logs
  ,Tripous.IconList
  ,o_App
  ,fr_QuickView
  ;


{ TfrComponentList }

procedure TfrComponentList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Components';

  PrepareToolBar();

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  Pager.ActivePage := tabText;

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;
  App.OnComponentListChanged := AppOnComponentListChanged;
  App.OnCategoryListChanged := AppOnCategoryListChanged;
  App.OnItemChanged := AppOnItemChanged;

  Grid.OnDblClick := GridOnDblClick;
  Grid.OnMouseDown := GridOnMouseDown;
  Grid.OnKeyDown := GridOnKeyDown;

  edtFilter.OnKeyDown := edtFilterOnKeyDown;
  edtFilter.OnChange := edtFilterOnTextChanged;

  ReLoad();
end;

procedure TfrComponentList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

procedure TfrComponentList.ReLoad();
var
  Id : string;
  List: TObjectList;
  i : Integer;
  Item: TSWComponent;
begin
  if Assigned(tblComponents) then
    Id := tblComponents.FieldByName('Id').AsString;

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
      tblComponents.First();
      List.Free();
    end;
  end;

  if (Id <> '') and Assigned(tblComponents) then
    tblComponents.Locate('Id', Id, []);

end;

procedure TfrComponentList.SelectedComponentChanged();
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

procedure TfrComponentList.FilterChanged();
var
  S: string;
begin
  S := Trim(edtFilter.Text);

  if (S <> '') and (Length(S) > 2) then
  begin
    // escape single quotes
    S := StringReplace(S, '''', '''''', [rfReplaceAll]);

    tblComponents.Filter :=
      Format(
        'Title LIKE ''%%%s%%'' OR Category LIKE ''%%%s%%'' OR TagList LIKE ''%%%s%%''',
        [S, S, S]
      );

    tblComponents.Filtered := True;

    SelectedComponentChanged;
  end
  else
  begin
    tblComponents.Filtered := False;
    tblComponents.Filter := '';
  end;

end;

procedure TfrComponentList.PrepareToolBar();
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  btnAddComponent := IconList.AddButton(ToolBar, 'table_add', 'New Add', AnyClick);
  btnEditComponent := IconList.AddButton(ToolBar, 'table_edit', 'Edit', AnyClick);
  btnDeleteComponent := IconList.AddButton(ToolBar, 'table_delete', 'Remove', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnEditText := IconList.AddButton(ToolBar, 'page_edit', 'Edit Text', AnyClick);
  btnAddToQuickView := IconList.AddButton(ToolBar, 'wishlist_add', 'Add selected Component to Quick View List', AnyClick);
end;

procedure TfrComponentList.AddToQuickView();
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
(*
DataRow Row = bsComponents.CurrentDataRow();
if (Row != null)
{
    string ComponentId = Row.AsString("Id");
    Component Component = App.CurrentProject.ComponentList.FirstOrDefault(x => x.Id == ComponentId);
    if (Component != null)
    {
        LinkItem LinkItem = new();
        LinkItem.ItemType = ItemType.Component;
        LinkItem.Place = LinkPlace.Title;
        LinkItem.Title = Component.Title;
        LinkItem.Item = Component;

        TabPage Page = App.SideBarPagerHandler.FindTabPage(nameof(UC_QuickView));
        if (Page != null)
        {
            UC_QuickView ucQuickViewList = Page.Tag as UC_QuickView;
            ucQuickViewList.AddToQuickView(LinkItem);
        }
    }
}
*)
end;

procedure TfrComponentList.AddComponent();
begin

end;

procedure TfrComponentList.DeleteComponent();
begin

end;

procedure TfrComponentList.EditComponent();
begin

end;

procedure TfrComponentList.EditComponentText();
begin

end;



procedure TfrComponentList.AnyClick(Sender: TObject);
begin
  if btnAddComponent = Sender then
    AddComponent()
  else if btnDeleteComponent = Sender then
    DeleteComponent()
  else if btnEditComponent = Sender then
    EditComponent()
  else if btnEditText = Sender then
    EditComponentText()
  else if btnAddToQuickView = Sender then
    AddToQuickView();
end;

procedure TfrComponentList.GridOnDblClick(Sender: TObject);
begin
  EditComponent();
end;

procedure TfrComponentList.GridOnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbRight) or (Button = mbMiddle) then
    EditComponentText();
end;

procedure TfrComponentList.GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_F2 then
  begin
    EditComponentText();
    Key := 0;
  end;
end;

procedure TfrComponentList.edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    FilterChanged;
    Key := 0;
  end;
end;

procedure TfrComponentList.edtFilterOnTextChanged(Sender: TObject);
var
  S: string;
begin
  S := Trim(edtFilter.Text);
  if S = '' then
     tblComponents.Filter := '';
end;



procedure TfrComponentList.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrComponentList.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrComponentList.AppOnComponentListChanged(Sender: TObject);
begin

end;

procedure TfrComponentList.AppOnCategoryListChanged(Sender: TObject);
begin

end;

procedure TfrComponentList.AppOnItemChanged(Sender: TObject; Item: TBaseItem);
begin

end;

procedure TfrComponentList.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;







end.

