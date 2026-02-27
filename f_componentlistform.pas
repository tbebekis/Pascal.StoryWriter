unit f_ComponentListForm;

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

  { TComponentListForm }

  TComponentListForm = class(TPageForm)
    edtFilter: TEdit;
    Grid: TDBGrid;
    Label1: TLabel;
    lboAliases: TListBox;
    lboTags: TListBox;
    Pager: TPageControl;
    pnlBottom: TPanel;
    pnlFilter: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    tabAliases: TTabSheet;
    tabTags: TTabSheet;
    tabText: TTabSheet;
    ToolBar: TToolBar;
  private
    tblComponents: TMemTable;
    DS: TDatasource;
    MarkdownPreview: TMarkdownPreview;

    btnAddComponent : TToolButton;
    btnEditComponent : TToolButton;
    btnDeleteComponent : TToolButton;
    btnEditText : TToolButton;
    btnAddToQuickView : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure GridOnDblClick(Sender: TObject);
    procedure GridOnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterOnTextChanged(Sender: TObject);
    procedure tblComponents_OnAfterScroll(Dataset: TDataset);

    procedure PrepareToolBar();

    procedure AddComponent();
    procedure EditComponent();
    procedure DeleteComponent();
    procedure EditComponentText();
    procedure AddToQuickView();

    procedure ReLoad();
    procedure SelectedComponentChanged();
    procedure FilterChanged();

    procedure AddToTable(Item: TSWComponent);
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    function ShowItemInList(Item: TSWComponent): Boolean;
  end;



implementation

{$R *.lfm}

uses
   LCLType
  ,Tripous.Logs
  ,o_Consts
  ,o_App
   ,f_ComponentForm
   ,f_QuickViewForm
  ,f_EditComponentDialog

  ;

{ TComponentListForm }

constructor TComponentListForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  MarkdownPreview := TMarkdownPreview.Create(Self);
  MarkdownPreview.Parent := tabText;
end;

destructor TComponentListForm.Destroy();
begin
  inherited Destroy();
end;

procedure TComponentListForm.FormInitialize;
begin
  ParentTabPage.Caption := 'Components';

  PrepareToolBar();

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  Pager.ActivePage := tabText;

  Grid.OnDblClick := GridOnDblClick;
  Grid.OnMouseDown := GridOnMouseDown;
  Grid.OnKeyDown := GridOnKeyDown;

  edtFilter.OnKeyDown := edtFilterOnKeyDown;
  edtFilter.OnChange := edtFilterOnTextChanged;

  ReLoad();
end;

procedure TComponentListForm.FormInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

function TComponentListForm.ShowItemInList(Item: TSWComponent): Boolean;
begin
  Result := False;
  if Assigned(Item) and Assigned(tblComponents) and (not tblComponents.IsEmpty) then
  begin
    Result := tblComponents.Locate('Id', Item.Id, []);
  end;
end;

procedure TComponentListForm.ReLoad();
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
        AddToTable(Item);
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

procedure TComponentListForm.SelectedComponentChanged();
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

procedure TComponentListForm.FilterChanged();
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

procedure TComponentListForm.AddToTable(Item: TSWComponent);
begin
  tblComponents.Append();
  tblComponents.FieldByName('Id').AsString := Item.Id;
  tblComponents.FieldByName('Title').AsString := Item.Title;
  tblComponents.FieldByName('Category').AsString := Item.Category;
  tblComponents.FieldByName('TagList').AsString := Item.GetTagsAsLine();
  tblComponents.Post();
end;

procedure TComponentListForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekCategoryListChanged: if Args.Sender <> Self then ReLoad();
    aekComponentListChanged: if Args.Sender <> Self then ReLoad();
  end;
end;

procedure TComponentListForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnAddComponent := AddButton(ToolBar, 'table_add', 'New Add', AnyClick);
    btnEditComponent := AddButton(ToolBar, 'table_edit', 'Edit', AnyClick);
    btnDeleteComponent := AddButton(ToolBar, 'table_delete', 'Remove', AnyClick);
    AddSeparator(ToolBar);
    btnEditText := AddButton(ToolBar, 'page_edit', 'Edit Text', AnyClick);
    btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected Component to Quick View List', AnyClick);
  finally
    ToolBar.Parent := P;
  end;


end;

procedure TComponentListForm.AddToQuickView();
var
  Id : string;
  Comp: TSWComponent;
  LinkItem : TLinkItem;
  TabPage : TTabSheet;
  frQuickView: TQuickViewForm;
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

  frQuickView := TQuickViewForm(TabPage.Tag);

  LinkItem := TLinkItem.Create(nil);
  LinkItem.Item := Comp;
  LinkItem.ItemType := itComponent;
  LinkItem.Place := lpTitle;
  LinkItem.Title := Comp.Title;

  frQuickView.AddToQuickView(LinkItem);

end;

procedure TComponentListForm.AddComponent();
var
  Message: string;
  Comp: TSWComponent;
  IsInsert: Boolean;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  Comp := TSWComponent.Create(nil);
  Comp.Title := 'New Component';
  Comp.Category := 'No Category';

  IsInsert := True;
  if TEditComponentDialog.Execute('Add Component', Comp, IsInsert) then
  begin
    App.CurrentProject.AddComponent(Comp);
    AddToTable(Comp);

    Message := Format('Component added: %s', [Comp.Title]);
    LogBox.AppendLine(Message);

    Broadcaster.Broadcast(SItemListChanged, Integer(itComponent), Self);
    Broadcaster.Broadcast(SComponentListChanged, Self);
  end;
end;

procedure TComponentListForm.EditComponent();
var
  Message: string;
  TabPage: TTabSheet;
  Id : string;
  Comp: TSWComponent;
  IsInsert: Boolean;
  frComponent: TComponentForm;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  if tblComponents.IsEmpty then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;
  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;


  IsInsert := False;
  if TEditComponentDialog.Execute('Add Component', Comp, IsInsert) then
  begin
    tblComponents.Edit();
    tblComponents.FieldByName('Title').AsString := Comp.Title;
    tblComponents.FieldByName('Category').AsString := Comp.Category;
    tblComponents.FieldByName('TagList').AsString := Comp.GetTagsAsLine();
    tblComponents.Post();

    TabPage := App.ContentPagerHandler.FindTabPage(Comp.Id);
    if Assigned(TabPage) then
    begin
      frComponent := TComponentForm(TabPage.Tag);
      frComponent.TitleChanged();
    end;

    Message := Format('Component updated: %s', [Comp.Title]);
    LogBox.AppendLine(Message);

    Broadcaster.Broadcast(SItemListChanged, Integer(itComponent), Self);
    Broadcaster.Broadcast(SComponentListChanged, Self);
  end;

end;

procedure TComponentListForm.DeleteComponent();
var
  Id : string;
  Comp: TSWComponent;
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblComponents) then
    Exit;

  if tblComponents.IsEmpty then
    Exit;

  Id := tblComponents.FieldByName('Id').AsString;

  Comp := App.CurrentProject.FindComponentById(Id);
  if not Assigned(Comp) then
    Exit;

  if not App.QuestionBox(Format('Are you sure you want to delete the component ''%s''?', [Comp.Title])) then
    Exit;

  App.ContentPagerHandler.ClosePage(Comp.Id);
  Comp.Delete();
  tblComponents.Delete();

  Message := Format('Component deleted: %s', [Comp.Title]);
  LogBox.AppendLine(Message);

  Broadcaster.Broadcast(SItemListChanged, Integer(itComponent), Self);
  Broadcaster.Broadcast(SComponentListChanged, Self);
end;

procedure TComponentListForm.EditComponentText();
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

procedure TComponentListForm.AnyClick(Sender: TObject);
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

procedure TComponentListForm.GridOnDblClick(Sender: TObject);
begin
  EditComponent();
end;

procedure TComponentListForm.GridOnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbRight) or (Button = mbMiddle) then
    EditComponentText();
end;

procedure TComponentListForm.GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_F2 then
  begin
    EditComponentText();
    Key := 0;
  end;
end;

procedure TComponentListForm.edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    FilterChanged;
    Key := 0;
  end;
end;

procedure TComponentListForm.edtFilterOnTextChanged(Sender: TObject);
var
  S: string;
begin
  S := Trim(edtFilter.Text);
  if S = '' then
     tblComponents.Filter := '';
end;

procedure TComponentListForm.tblComponents_OnAfterScroll(Dataset: TDataset);
begin
  SelectedComponentChanged();
end;



end.

