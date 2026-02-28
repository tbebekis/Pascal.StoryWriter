unit f_NoteListForm;

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
  , Menus
  , DB
  , DBCtrls
  , DBGrids
  , f_PageForm
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities
  , f_TextEditorForm
  , o_TextEditor
  ;

type

  { TNoteListForm }

  TNoteListForm = class(TPageForm)
    edtFilter: TEdit;
    Grid: TDBGrid;
    Label1: TLabel;
    pnlBottom: TPanel;
    pnlFilter: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    ToolBar: TToolBar;
  private
    btnAddNote : TToolButton;
    btnEditNote : TToolButton;
    btnDeleteNote : TToolButton;
    btnEditText : TToolButton;
    btnAddToQuickView : TToolButton;
    btnUp : TToolButton;
    btnDown : TToolButton;

    tblNotes : TMemTable;
    DS: TDatasource;
    frmText: TTextEditorForm;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterOnTextChanged(Sender: TObject);
    procedure tblNotes_OnAfterScroll(Dataset: TDataset);

    procedure ReLoad();

    procedure SelectedRowChanged();
    procedure FilterChanged();

    procedure PrepareToolBar();

    procedure AddNote();
    procedure EditNote();
    procedure DeleteNote();
    procedure EditNoteText();

    procedure AddToQuickView();
    procedure MoveRow(Up: Boolean);

    // ● table
    procedure EnsureTable();
    procedure DisposeTable();
    procedure AddToTable(Note: TNote);
    function  GetId(): string;
    procedure GotToId(const Id: string);
    function  GetItem(): TNote;
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    function LocateItemInList(Note: TNote): Boolean;

    { editor handler }
    procedure SaveEditorText(TextEditor: TTextEditor); override;

    procedure AdjustTabTitle(); override;
    function ShowItemInList(Item: TNote): Boolean;
  end;



implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
   , LCLType
  ,o_Consts
  ,o_App
  ,f_QuickViewForm
  ,f_NoteForm
  ,f_EditItemDialog
  ;

{ TNoteListForm }

constructor TNoteListForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := pnlBottom;

  frmText.FramePage := Self;
  //frmText.ToolBarVisible := False;
  //frmText.TextEditor.ReadOnly := True;
end;

destructor TNoteListForm.Destroy();
begin
  inherited Destroy();
end;

procedure TNoteListForm.FormInitialize;
begin
  frmText.Visible := True;
  ParentTabPage.Caption := 'Notes';

  PrepareToolBar();

  Grid.OnKeyDown := GridOnKeyDown;

  edtFilter.OnKeyDown := edtFilterOnKeyDown;
  edtFilter.OnChange  := edtFilterOnTextChanged;

  ReLoad();
end;

procedure TNoteListForm.FormInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

procedure TNoteListForm.AddToTable(Note: TNote);
begin
  tblNotes.Append();

  tblNotes.FieldByName('Id').AsString := Note.Id;
  tblNotes.FieldByName('Title').AsString := Note.Title;
  tblNotes.Post();
end;

function TNoteListForm.GetId(): string;
begin
  Result := '';
  if Assigned(tblNotes) and (not tblNotes.IsEmpty) then
    Result := tblNotes.FieldByName('Id').AsString;
end;

procedure TNoteListForm.GotToId(const Id: string);
begin
  if (Id <> '') and Assigned(tblNotes) and (not tblNotes.IsEmpty)  then
    tblNotes.Locate('Id', Id, []);
end;

function TNoteListForm.GetItem(): TNote;
var
  Id : string;
begin
  Result := nil;
  Id := GetId();
  if Id <> '' then
    Result := App.CurrentProject.FindNoteById(Id);
end;

procedure TNoteListForm.EnsureTable();
begin
  if not Assigned(tblNotes) then
  begin
    tblNotes := TMemTable.Create(Self);

    tblNotes.FieldDefs.Add('Id', ftString, 100);
    tblNotes.FieldDefs.Add('Title', ftString, 200);
    tblNotes.CreateDataset;

    DS := TDataSource.Create(Self);
    DS.DataSet := tblNotes;

    Grid.Columns.Clear();
    App.InitializeReadOnly(Grid);
    App.AddColumn(Grid, 'Title', 'Note');
    Grid.DataSource := DS;

    App.AdjustGridColumns(Grid, 200);

    tblNotes.Active := True;
    tblNotes.AfterScroll := tblNotes_OnAfterScroll;
  end;
end;

procedure TNoteListForm.DisposeTable();
begin
  Grid.Columns.Clear();
  Grid.DataSource := nil;
  if Assigned(DS) then
    DS.DataSet := nil;

  if Assigned(tblNotes) then
  begin
    tblNotes.AfterScroll := nil;
    tblNotes.Active := False;
    tblNotes.Free();
    tblNotes := nil;
  end;
end;

procedure TNoteListForm.ReLoad();
var
  Id : string;
  Note: TCollectionItem;
  NoteList: TNoteCollection;
begin
  Id := GetId();
  DisposeTable();
  EnsureTable();

  if Assigned(App.CurrentProject) then
  begin
    NoteList := App.CurrentProject.NoteList;

    tblNotes.DisableControls();
    try
      tblNotes.EmptyDataSet();
      tblNotes.CancelUpdates();
      for Note in NoteList do
        AddToTable(TNote(Note));
    finally
      tblNotes.EnableControls();
      tblNotes.First();
    end;
  end;

  GotToId(Id);

  SelectedRowChanged();
end;

procedure TNoteListForm.SelectedRowChanged();
var
  Note: TNote;
  DocText: string;
begin
  TitleText := 'No selection';
  pnlTitle.Caption := TitleText;
  frmText.EditorText := '';

  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  if tblNotes.IsEmpty then
    Exit;

  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  TitleText := Note.Title;
  pnlTitle.Caption := TitleText;

  DocText := Note.Text;
  frmText.EditorText := DocText;

end;

procedure TNoteListForm.AdjustTabTitle();
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if frmText.Modified then
    pnlTitle.Caption := TitleText + '*'
  else
    pnlTitle.Caption := TitleText;
end;

function TNoteListForm.ShowItemInList(Item: TNote): Boolean;
begin
  Result := False;
  if Assigned(Item) and Assigned(tblNotes) and (not tblNotes.IsEmpty) then
  begin
    Result := tblNotes.Locate('Id', Item.Id, []);
  end;
end;

procedure TNoteListForm.FilterChanged();
var
  S: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  S := Trim(edtFilter.Text);
  if Length(S) > 2 then
  begin
    tblNotes.Filter := 'Title LIKE ''%' + S + '%''';
    tblNotes.Filtered := True;
    SelectedRowChanged();
  end else begin
    tblNotes.Filter := '';
  end;
end;

procedure TNoteListForm.AddToQuickView();
var
  Note: TNote;
  LinkItem : TLinkItem;
  TabPage : TTabSheet;
  QuickViewForm: TQuickViewForm;
begin
  if not Assigned(App.CurrentProject) then
    Exit;
  if not Assigned(tblNotes) then
    Exit;

  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  TabPage :=  App.SideBarPagerHandler.ShowPage(TQuickViewForm, TQuickViewForm.ClassName, nil);
  if (not Assigned(TabPage)) or (TabPage.Tag = 0) then
    Exit;

  QuickViewForm := TQuickViewForm(TabPage.Tag);

  LinkItem := TLinkItem.Create(nil);
  LinkItem.Item := Note;
  LinkItem.ItemType := itNote;
  LinkItem.Place := lpTitle;
  LinkItem.Title := Note.Title;

  QuickViewForm.AddToQuickView(LinkItem);
end;

function TNoteListForm.LocateItemInList(Note: TNote): Boolean;
var
  Filter: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;
  if not Assigned(tblNotes) then
    Exit;

  Filter := edtFilter.Text;
  edtFilter.Text := '';

  Result := tblNotes.Locate('Id', Note.Id, []);

  if not Result then
  begin
    edtFilter.Text := Filter;
  end;
end;

procedure TNoteListForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnAddNote := AddButton(ToolBar, 'table_add', 'New Note', AnyClick);
    btnEditNote := AddButton(ToolBar, 'table_edit', 'Edit Note', AnyClick);
    btnDeleteNote := AddButton(ToolBar, 'table_delete', 'Remove Note', AnyClick);
    AddSeparator(ToolBar);
    // btnEditText := AddButton(ToolBar, 'page_edit', 'Edit Note Text', AnyClick);      // No we do NOT use this, we edit Note text in this UI
    btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected Note to Quick View List', AnyClick);
    AddSeparator(ToolBar);
    btnUp := AddButton(ToolBar, 'arrow_up', 'Move Up', AnyClick);
    btnDown := AddButton(ToolBar, 'arrow_down', 'Move Down', AnyClick);
  finally
    ToolBar.Parent := P;
  end;


end;

procedure TNoteListForm.AnyClick(Sender: TObject);
begin
  if btnAddNote = Sender then
    AddNote()
  else if btnEditNote = Sender then
    EditNote()
  else if btnDeleteNote = Sender then
    DeleteNote()
  else if btnEditText = Sender then
    EditNoteText()
  else if btnAddToQuickView = Sender then
    AddToQuickView()
  else if btnUp = Sender then
    MoveRow(True)
  else if btnDown = Sender then
    MoveRow(False);

end;

procedure TNoteListForm.GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_F2 then
  begin
    EditNoteText();
    Key := 0;
  end;
end;

procedure TNoteListForm.edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    FilterChanged();
    Key := 0;
  end;
end;

procedure TNoteListForm.edtFilterOnTextChanged(Sender: TObject);
var
  S: string;
begin
  S := Trim(edtFilter.Text);
  if S = '' then
     tblNotes.Filter := '';
end;

procedure TNoteListForm.tblNotes_OnAfterScroll(Dataset: TDataset);
begin
  SelectedRowChanged();
end;

procedure TNoteListForm.AddNote();
var
  Message: string;
  ResultName: string;
  Note: TNote;
  Count: Integer;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  Message := '';
  ResultName := '';

  if TEditItemDialog.ShowDialog('Add Note', App.CurrentProject.Title, ResultName) then
  begin

    Count := App.CurrentProject.CountNoteTitle(ResultName);
    if Count > 0 then
    begin
      Message := Format('Note already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Note := App.CurrentProject.AddNote(ResultName);
    AddToTable(Note);

    Message := Format('Note added: %s', [ResultName]);
    LogBox.AppendLine(Message);

    Broadcaster.Broadcast(SItemListChanged, Integer(itNote), Self);
  end;

end;

procedure TNoteListForm.EditNote();
var
  Message: string;
  ResultName: string;
  Note: TNote;
  Count: Integer;
  TabPage: TTabSheet;
  NoteForm : TNoteForm;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  if tblNotes.IsEmpty then
    Exit;

  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  Message := '';
  ResultName := Note.Title;

  if TEditItemDialog.ShowDialog('Edit Note', App.CurrentProject.Title, ResultName) then
  begin

    Count := App.CurrentProject.CountNoteTitle(ResultName);
    if Count > 0 then
    begin
      Message := Format('Note already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Note.Title := ResultName;

    TabPage := App.ContentPagerHandler.FindTabPage(Note.Id);
    if Assigned(TabPage) then
    begin
      NoteForm := TNoteForm(TabPage.Tag);
      NoteForm.TitleChanged();
    end;

    Message := Format('Note updated: %s', [ResultName]);
    LogBox.AppendLine(Message);

    Broadcaster.Broadcast(SItemChanged, Note, Self);
    Broadcaster.Broadcast(SItemListChanged, Integer(itNote), Self);
  end;

end;

procedure TNoteListForm.DeleteNote();
var
  Message: string;
  Note: TNote;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  if tblNotes.IsEmpty then
    Exit;

  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  Message := Format('Are you sure you want to delete the Note: %s', [Note.Title]);
  if not App.QuestionBox(Message) then
    Exit;

  App.ContentPagerHandler.ClosePage(Note.Id);
  Note.Delete();
  tblNotes.Delete();

  Message := Format('Note deleted: %s', [Note.Title]);
  LogBox.AppendLine(Message);

  Broadcaster.Broadcast(SItemListChanged, Integer(itNote), Self);

end;

procedure TNoteListForm.EditNoteText();
var
  Note: TNote;
begin
  // No we do NOT use this, we edit Note text in this UI
  Exit;

  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  if tblNotes.IsEmpty then
    Exit;

  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  App.ContentPagerHandler.ShowPage(TNoteForm, Note.Id, Note);
end;

procedure TNoteListForm.MoveRow(Up: Boolean);
var
  Id : string;
  Note: TNote;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  if tblNotes.IsEmpty then
    Exit;

  Id := GetId();
  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  if Note.Move(Up) then
  begin
    ReLoad();
    tblNotes.Locate('Id', Id, []);
  end;

end;

procedure TNoteListForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
  Note: TNote;
begin
  Note := GetItem();
  if not Assigned(Note) then
    Exit;

  Note.Text := TextEditor.EditorText;
  Note.Save();

  Message := Format('Note text saved: %s', [Note.DisplayTitle]);
  LogBox.AppendLine(Message);

  TextEditor.Modified := False;
  AdjustTabTitle();

end;


end.

