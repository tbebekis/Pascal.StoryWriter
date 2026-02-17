unit f_EditComponentDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls
  , LCLType
  ,o_Entities
  ;

type

  { TEditComponentDialog }

  TEditComponentDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    btnAddCategory: TButton;
    btnSelectAll: TButton;
    btnSelectOne: TButton;
    btnUnselectOne: TButton;
    btnUnselectAll: TButton;
    btnAddTags: TButton;
    edtCategory: TEdit;
    edtTags: TEdit;
    edtTitle: TEdit;
    edtAliases: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    lboCategory: TListBox;
    lboAvail: TListBox;
    lboSelected: TListBox;
  private
    IsInsert: Boolean;
    Comp: TSWComponent;

    CategoryList: TStringList;
    TagList: TStringList;            // all tags
    AvailList: TStringList;
    SelectedList: TStringList;

    procedure FormInitialize();

    procedure ItemToControls();
    procedure ControlsToItem();

    procedure AddCategory();
    procedure AddTags();

    procedure SelectAll();
    procedure UnSelectAll();
    procedure SelectOne();
    procedure UnSelectOne();

    procedure SetSelectedAfterSelectOne(Box: TListBox; LastSelectedIndex: Integer);

    function ListContains(List: TStrings; const Item: string): Boolean;
    procedure ListAdd(List: TStrings; const Item: string);
    procedure ListRemove(List: TStrings; const Item: string);

    procedure UpdateListBox(Box: TListBox; List: TStrings);
    procedure UpdateListBoxes();

    procedure AnyClick(Sender: TObject);
    procedure AnyListBox_OnDblClick(Sender: TObject);
    procedure AnyEditBox_OnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    class function Execute(const DialogTitle: string; AComp: TSWComponent; AIsInsert: Boolean): Boolean;
  end;

var
  EditComponentDialog: TEditComponentDialog;

implementation

{$R *.lfm}

uses
  Tripous.Logs
  ,o_App
  ;

{ TEditComponentDialog }

constructor TEditComponentDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  CategoryList := TStringList.Create();
  TagList := TStringList.Create();        // all tags
  AvailList := TStringList.Create();
  SelectedList := TStringList.Create();

  CategoryList.Sorted := True;
  AvailList.Sorted := True;
  SelectedList.Sorted := True;

  btnOK.Default := True;
  btnCancel.Cancel := True;

  btnOK.OnClick := AnyClick;
  btnAddCategory.OnClick := AnyClick;
  btnSelectAll.OnClick := AnyClick;
  btnSelectOne.OnClick := AnyClick;
  btnUnselectOne.OnClick := AnyClick;
  btnUnselectAll.OnClick := AnyClick;
  btnAddTags.OnClick := AnyClick;

  lboAvail.OnDblClick := AnyListBox_OnDblClick;
  lboSelected.OnDblClick := AnyListBox_OnDblClick;

  Self.Height := 750;
end;

destructor TEditComponentDialog.Destroy();
begin
  FreeAndNil(CategoryList);
  FreeAndNil(TagList);
  FreeAndNil(AvailList);
  FreeAndNil(SelectedList);

  inherited Destroy();
end;

procedure TEditComponentDialog.FormInitialize();
begin
  ItemToControls();

  if edtTitle.CanFocus() then
    edtTitle.SetFocus();

  edtTitle.SelectAll();
end;

procedure TEditComponentDialog.ItemToControls();
var
  Tag: string;
begin
  edtTitle.Text := Comp.Title;
  edtAliases.Text := Comp.Aliases;

  // categories
  CategoryList.AddStrings(App.CurrentProject.GetCategoryList());
  lboCategory.Items.AddStrings(CategoryList);
  if CategoryList.IndexOf(Comp.Category) <> -1 then
     lboCategory.ItemIndex := CategoryList.IndexOf(Comp.Category);

  // tags
  TagList.AddStrings(App.CurrentProject.GetTagList);
  SelectedList.AddStrings(Comp.TagList);
  AvailList.AddStrings(TagList);

  for Tag in Comp.TagList do
      ListAdd(SelectedList, Tag);

  UpdateListBoxes();
end;

procedure TEditComponentDialog.ControlsToItem();
var
  Message: string;
  Count, MaxCount: Integer;
begin
  if not App.IsValidFileName(Trim(edtTitle.Text), true) then
     Exit;

  if lboCategory.ItemIndex < 0 then
  begin
    Message := 'Please select a category.';
    App.ErrorBox(Message);
    LogBox.AppendLine(Message);
    Exit;
  end;

  Count := App.CurrentProject.CountComponentTitle(Trim(edtTitle.Text));
  MaxCount := 1;
  if IsInsert then
    MaxCount := 0;

  if Count > MaxCount then
  begin
    Message := Format('Component already exists: %s', [Trim(edtTitle.Text)]);
    App.ErrorBox(Message);
    LogBox.AppendLine(Message);
    Exit;
  end;

  Comp.Title := Trim(edtTitle.Text);
  Comp.Aliases := Trim(edtAliases.Text);
  Comp.Category := lboCategory.Items[lboCategory.ItemIndex];
  Comp.SetTagsFrom(SelectedList);

  Self.ModalResult := mrOK;

end;

procedure TEditComponentDialog.AddCategory();
var
  Category: string;
  Index : Integer;
begin
  Category := Trim(edtCategory.Text);
  if not App.IsValidFileName(Category, True) then
    Exit;

  if not ListContains(CategoryList, Category) then
    ListAdd(CategoryList, Category);

  Index := lboCategory.Items.IndexOf(Category);
  if Index < 0 then
  begin
    lboCategory.Items.Add(Category);
    lboCategory.ItemIndex := lboCategory.Items.Count - 1;
  end else begin
    lboCategory.ItemIndex := Index;
  end;
end;

procedure TEditComponentDialog.AddTags();
var
  Tags: string;
  Parts: TArray<string>;
  Part: string;
  I: Integer;

begin
  Tags := Trim(edtTags.Text);
  if Tags = '' then
    Exit;

  Parts := Tags.Split([','], TStringSplitOptions.ExcludeEmpty);
  for I := 0 to Length(Parts) - 1 do
    Parts[I] := Trim(Parts[I]);

  for Part in Parts do
  begin
    if not ListContains(TagList, Part) then
    begin
      ListAdd(TagList, Part);
      ListAdd(AvailList, Part);
    end;

    if not ListContains(SelectedList, Part) then
    begin
      ListAdd(SelectedList, Part);
      ListRemove(AvailList, Part);
    end;
  end;

  UpdateListBoxes();

  edtTags.Text := '';
end;

procedure TEditComponentDialog.SelectAll();
begin
  SelectedList.AddStrings(AvailList);
  AvailList.Clear();
  UpdateListBoxes();
end;

procedure TEditComponentDialog.UnSelectAll();
begin
  AvailList.AddStrings(SelectedList);
  SelectedList.Clear();
  UpdateListBoxes();
end;

procedure TEditComponentDialog.SelectOne();
var
  Item: string;
  LastSelectedIndex: Integer;
  Index: Integer;
begin
  if lboAvail.ItemIndex <> -1 then
  begin
    Item := lboAvail.Items[lboAvail.ItemIndex];
    LastSelectedIndex := lboAvail.ItemIndex;

    ListRemove(AvailList, Item);
    ListAdd(SelectedList, Item);

    UpdateListBoxes();

    Index := lboSelected.Items.IndexOf(Item);
    if Index <> -1 then
      lboSelected.ItemIndex := Index;

    SetSelectedAfterSelectOne(lboAvail, LastSelectedIndex);
  end;

end;

procedure TEditComponentDialog.UnSelectOne();
var
  Item: string;
  LastSelectedIndex: Integer;
  Index: Integer;
begin
  if lboSelected.ItemIndex <> -1 then
  begin
    Item := lboSelected.Items[lboSelected.ItemIndex];
    LastSelectedIndex := lboSelected.ItemIndex;

    ListRemove(SelectedList, Item);
    ListAdd(AvailList, Item);

    UpdateListBoxes();

    Index := lboAvail.Items.IndexOf(Item);
    if Index <> -1 then
      lboAvail.ItemIndex := Index;


    SetSelectedAfterSelectOne(lboSelected, LastSelectedIndex);

  end;
end;

procedure TEditComponentDialog.SetSelectedAfterSelectOne(Box: TListBox; LastSelectedIndex: Integer);
begin
  if (LastSelectedIndex > 0) and (Box.Items.Count > 0) then
     Box.ItemIndex := LastSelectedIndex - 1;
end;

function TEditComponentDialog.ListContains(List: TStrings; const Item: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if List = nil then
    Exit;

  for I := 0 to List.Count - 1 do
    if SameText(List[I], Item) then
      Exit(True);
end;

procedure TEditComponentDialog.ListAdd(List: TStrings; const Item: string);
begin
  if (List <> nil) and (not ListContains(List, Item)) then
    List.Add(Item);
end;

procedure TEditComponentDialog.ListRemove(List: TStrings; const Item: string);
var
  I: Integer;
begin
  if List = nil then
    Exit;

  for I := 0 to List.Count - 1 do
  begin
    if SameText(List[I], Item) then
    begin
      List.Delete(I);
      Exit;
    end;
  end;
end;

procedure TEditComponentDialog.UpdateListBox(Box: TListBox; List: TStrings);
begin
  Box.Items.BeginUpdate();
  Box.Items.Clear();
  Box.Items.AddStrings(List);
  Box.Items.EndUpdate();
end;

procedure TEditComponentDialog.UpdateListBoxes();
begin
  UpdateListBox(lboAvail, AvailList);
  UpdateListBox(lboSelected, SelectedList);
end;

procedure TEditComponentDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem()
  else if btnAddCategory = Sender then
    AddCategory()
  else if btnAddTags = Sender then
    AddTags()
  else if btnSelectAll = Sender then
    SelectAll()
  else if btnUnselectAll = Sender then
    UnSelectAll()
  else if btnSelectOne = Sender then
    SelectOne()
  else if btnUnselectOne = Sender then
    UnSelectOne();
end;

procedure TEditComponentDialog.AnyListBox_OnDblClick(Sender: TObject);
begin
  if lboAvail = Sender then
    SelectOne()
  else if lboSelected = Sender then
    UnSelectOne();
end;

procedure TEditComponentDialog.AnyEditBox_OnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if edtCategory = Sender then
    begin
      AddCategory();
      Key := 0;
    end
    else if btnAddTags = Sender then
    begin
      AddTags();
      Key := 0;
    end;
  end;
end;

procedure TEditComponentDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

class function TEditComponentDialog.Execute(const DialogTitle: string; AComp: TSWComponent; AIsInsert: Boolean): Boolean;
var
  Dlg: TEditComponentDialog;
begin
  Result := False;

  Dlg := TEditComponentDialog.Create(nil);
  try
    Dlg.Caption := DialogTitle;
    Dlg.IsInsert := AIsInsert;
    Dlg.Comp := AComp;
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;

end;
end.

