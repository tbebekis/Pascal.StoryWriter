unit fr_NoteList;

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
  , LCLIntf
  , DB
  , DBCtrls
  , DBGrids
  , Tripous.Forms.FramePage
  , Tripous.MemTable
  , o_Entities
  , fr_TextEditor
  ;


type

  { TfrNoteList }

  TfrNoteList = class(TFramePage)
    edtFilter: TEdit;
    frText: TfrTextEditor;
    Grid: TDBGrid;
    Label1: TLabel;
    pnlBottom: TPanel;
    pnlFilter: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    StatusBar: TStatusBar;
    ToolBar: TToolBar;
    ToolBar1: TToolBar;
  private
    fSelectedNote: TNote;
    SettingText: Boolean;
    TitleText : string;
    procedure SetSelectedNote(AValue: TNote);
  private
    tblNotes : TMemTable;
    DS: TDatasource;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnItemChanged(Sender: TObject; Item: TBaseItem);

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

    property SelectedNote : TNote read fSelectedNote write SetSelectedNote;
  protected
    procedure AdjustTabTitle(); override;
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    function ShowItemInList(Note: TNote): Boolean;
    procedure UpdateComponentListNote(const NoteText: string);

    { editor handler }
    procedure SaveEditorText(TextEditor: TfrTextEditor); override;
    procedure GlobalSearchForTerm(const Term: string); override;
  end;

implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_App
  ,fr_QuickView
  ;


{ TfrNoteList }

procedure TfrNoteList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Notes';

  PrepareToolBar();

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  frText.ToolBarVisible := False;
  frText.Editor.ReadOnly := True;

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;
  App.OnItemChanged := AppOnItemChanged;

  Grid.OnKeyDown := GridOnKeyDown;

  edtFilter.OnKeyDown := edtFilterOnKeyDown;
  edtFilter.OnChange  := edtFilterOnTextChanged;

  ReLoad();
end;

procedure TfrNoteList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

procedure TfrNoteList.ReLoad();
var
  Id : string;
  Note: TCollectionItem;
  NoteList: TNoteCollection;
begin

  if Assigned(tblNotes) then
    Id := tblNotes.FieldByName('Id').AsString;

  if not Assigned(tblNotes) then
  begin
    tblNotes := TMemTable.Create(Self);
    tblNotes.FieldDefs.Add('Id', ftString, 100);
    tblNotes.FieldDefs.Add('Title', ftString, 200);
    tblNotes.CreateDataset;

    DS := TDataSource.Create(Self);
    DS.DataSet := tblNotes;

    App.InitializeReadOnly(Grid);
    App.AddColumn(Grid, 'Title', 'Note');
    Grid.DataSource := DS;

    App.AdjustGridColumns(Grid, 200);

    tblNotes.Active := True;
    tblNotes.AfterScroll := tblNotes_OnAfterScroll;
  end;

  if Assigned(App.CurrentProject) then
  begin
    NoteList := App.CurrentProject.NoteList;

    tblNotes.DisableControls();
    try
      tblNotes.EmptyDataSet();

      for Note in NoteList do
      begin
        tblNotes.Append();
        tblNotes.FieldByName('Id').AsString := TNote(Note).Id;
        tblNotes.FieldByName('Title').AsString := TNote(Note).Title;
        tblNotes.Post();
      end;
    finally
      tblNotes.EnableControls();
      tblNotes.First();
    end;
  end;

  if (Id <> '') and Assigned(tblNotes) then
    tblNotes.Locate('Id', Id, []);

  SelectedRowChanged();

end;

procedure TfrNoteList.SetSelectedNote(AValue: TNote);
begin
  if fSelectedNote = AValue then
    Exit;

  fSelectedNote := AValue;

  SettingText := True;
  try
    if Assigned(fSelectedNote) then
    begin
      TitleText := fSelectedNote.Title;
      pnlTitle.Caption := TitleText;
      frText.EditorText := fSelectedNote.Text;
    end else begin
      TitleText := 'No selection';
      pnlTitle.Caption := TitleText;
      frText.EditorText := '';
    end;
  finally
    SettingText := False;
  end;

end;

procedure TfrNoteList.SelectedRowChanged();
var
  Id : string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if not Assigned(tblNotes) then
    Exit;

  SelectedNote := nil;

  if tblNotes.IsEmpty then
    Exit;

  Id := tblNotes.FieldByName('Id').AsString;
  SelectedNote := App.CurrentProject.FindNoteById(Id);
end;

procedure TfrNoteList.AdjustTabTitle();
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if frText.Modified then
    pnlTitle.Caption := TitleText + '*'
  else
    pnlTitle.Caption := TitleText;

end;

procedure TfrNoteList.FilterChanged();
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

procedure TfrNoteList.AddToQuickView();
var
  Id : string;
  Note: TNote;
  LinkItem : TLinkItem;
  TabPage : TTabSheet;
  QuickView: TfrQuickView;
begin
  if not Assigned(App.CurrentProject) then
    Exit;
  if not Assigned(tblNotes) then
    Exit;

  Id := tblNotes.FieldByName('Id').AsString;
  Note := App.CurrentProject.FindNoteById(Id);

  if not Assigned(Note) then
    Exit;

  TabPage :=  App.SideBarPagerHandler.ShowPage(TfrQuickView, TfrQuickView.ClassName, nil);
  if (not Assigned(TabPage)) or (TabPage.Tag = 0) then
    Exit;

  QuickView := TfrQuickView(TabPage.Tag);

  LinkItem := TLinkItem.Create(nil);
  LinkItem.Item := Note;
  LinkItem.ItemType := itNote;
  LinkItem.Place := lpTitle;
  LinkItem.Title := Note.Title;

  QuickView.AddToQuickView(LinkItem);
end;

function TfrNoteList.ShowItemInList(Note: TNote): Boolean;
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

procedure TfrNoteList.PrepareToolBar();
begin

end;

procedure TfrNoteList.AnyClick(Sender: TObject);
begin

end;

procedure TfrNoteList.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrNoteList.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrNoteList.AppOnItemChanged(Sender: TObject; Item: TBaseItem);
begin

end;

procedure TfrNoteList.GridOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin

end;

procedure TfrNoteList.edtFilterOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    FilterChanged();
    Key := 0;
  end;
end;

procedure TfrNoteList.edtFilterOnTextChanged(Sender: TObject);
var
  S: string;
begin
  S := Trim(edtFilter.Text);
  if S = '' then
     tblNotes.Filter := '';
end;

procedure TfrNoteList.tblNotes_OnAfterScroll(Dataset: TDataset);
begin
  SelectedRowChanged();
end;



procedure TfrNoteList.AddNote();
begin

end;

procedure TfrNoteList.EditNote();
begin

end;

procedure TfrNoteList.DeleteNote();
begin

end;

procedure TfrNoteList.EditNoteText();
begin

end;

procedure TfrNoteList.MoveRow(Up: Boolean);
begin

end;

{ There is a standard Note entry, called "Component List" which displays a list of components.
  This method updates the text of that note. }
procedure TfrNoteList.UpdateComponentListNote(const NoteText: string);
begin

end;



procedure TfrNoteList.SaveEditorText(TextEditor: TfrTextEditor);
begin
  inherited SaveEditorText(TextEditor);
end;

procedure TfrNoteList.GlobalSearchForTerm(const Term: string);
begin
  inherited GlobalSearchForTerm(Term);
end;

end.

