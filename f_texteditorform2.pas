unit f_TextEditorForm2;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , ComCtrls
  , ExtCtrls
  , LCLType

  , f_PageForm
  , o_TextEditor
  , o_FindAndReplace
  ;

type

  { TTextEditorForm2 }

  TTextEditorForm2 = class(TForm)
    StatusBar: TStatusBar;
    ToolBar: TToolBar;
  private
    btnSave: TToolButton;
    btnFind: TToolButton;
    btnShowFolder: TToolButton;
    btnClose: TToolButton;

    FAutoSaveTimer: TTimer;
    fFindAndReplaceOptions: TFindAndReplaceOptions;
    FLastEditTick: QWord;
    FAutoSaveDirty: Boolean;
    FAutoSaveIdleMs: Integer;
    fTextEditor: TTextEditor;

    IsHighlighterRegistered: Boolean;
    IsInitialized: Boolean;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure Editor_Change(Sender: TObject);
    procedure Editor_ModifiedChanged(Sender: TObject);
    procedure Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Editor_CaretChangedPos(Sender: TObject);
    procedure Editor_ChangeZoom(Sender: TObject);

    procedure AutoSaveTimerTick(Sender: TObject);

    procedure FormInitialize();
    procedure PrepareToolBar();

    procedure UpdateStatusBarLineColumn();
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure Save();
    procedure UpdateStatusBar();

    property TextEditor: TTextEditor read fTextEditor;
    property FindAndReplaceOptions : TFindAndReplaceOptions read fFindAndReplaceOptions;

  end;



implementation

{$R *.lfm}

uses
  Math
  ,o_App
  ,o_Highlighters
  ,o_Filer
  ;


{ TTextEditorForm }

constructor TTextEditorForm2.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fFindAndReplaceOptions := TFindAndReplaceOptions.Create;

  fTextEditor := TTextEditor.Create(Self);
  TextEditor.Parent := Self;
end;

destructor TTextEditorForm2.Destroy();
begin
  if IsHighlighterRegistered then
     THighlighters.UnregisterEditor(TextEditor);

  fFindAndReplaceOptions.Free();
  inherited Destroy();
end;

procedure TTextEditorForm2.DoShow;
begin
  inherited DoShow;
  if not IsInitialized then
  begin
    FormInitialize();
    IsInitialized := True;
  end;
end;

procedure TTextEditorForm2.FormInitialize();
begin
  TextEditor.Modified := False;
  TextEditor.WordWrap := True;

  FAutoSaveIdleMs := 1000 * 3;
  FAutoSaveDirty := False;
  FLastEditTick := GetTickCount64;

  FAutoSaveTimer := TTimer.Create(Self);
  FAutoSaveTimer.Enabled := False;
  FAutoSaveTimer.OnTimer := AutoSaveTimerTick;

  FAutoSaveTimer.Interval := App.Settings.AutoSaveSecondsInterval * 1000;
  FAutoSaveTimer.Enabled := App.Settings.AutoSave;

  PrepareToolBar();

  TextEditor.OnKeyDown := Editor_KeyDown;
  TextEditor.OnChange := Editor_Change;
  TextEditor.OnModifiedChanged := Editor_ModifiedChanged;
  TextEditor.OnChangeCaretPos := Editor_CaretChangedPos;
  TextEditor.OnChangeZoom := Editor_ChangeZoom;

  TextEditor.SetFocus();

  (*
  if App.Settings.UseHighlighters and FileExists(Doc.FilePath) then
  begin
    THighlighters.ApplyToEditor(TextEditor.Editor, Doc.FilePath);
    TextEditor.Editor.Invalidate;
    TextEditor.Editor.Update;
    IsHighlighterRegistered := True;
  end;
  *)

  UpdateStatusBar();
end;

procedure TTextEditorForm2.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnSave  := AddButton(ToolBar, 'DISK', 'Save', AnyClick);
    btnFind := AddButton(ToolBar, 'PAGE_FIND', 'Find', AnyClick);
    btnToggleWordWrap := AddButton(ToolBar, 'TEXT_DOCUMENT_WRAP', 'Word Wrap', AnyClick);
    btnShowFolder := AddButton(ToolBar, 'FOLDER_GO', 'Show in folder', AnyClick);
    btnClose := AddButton(ToolBar, 'DOOR_OUT', 'Close', AnyClick);
    //AddSeparator(ToolBar);
  finally
    ToolBar.Parent := P;
  end;

end;

procedure TTextEditorForm2.AnyClick(Sender: TObject);
begin
  if btnSave = Sender then
    Save()
  else if btnFind = Sender then
    TextEditor.ShowFindAndReplaceDialog()
  else if btnShowFolder = Sender then
    App.DisplayFileExplorer(Doc.RealFilePath)
  else if btnToggleWordWrap = Sender then
    TextEditor.WordWrap := not TextEditor.WordWrap
  else if btnClose = Sender then
    App.ClosePage(Id);

end;

procedure TTextEditorForm2.Save();
begin

end;

procedure TTextEditorForm2.Editor_Change(Sender: TObject);
begin
  FAutoSaveDirty := True;              // something is written, start "idle countdown"
  FLastEditTick := GetTickCount64;
end;

procedure TTextEditorForm2.Editor_ModifiedChanged(Sender: TObject);
begin

end;

procedure TTextEditorForm2.Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    Save();
  end

  (*
  if (Shift = [ssCtrl]) and (Key = VK_F) then
  begin
    Key := 0;
    ShowFindAndReplaceDialog();
  end
  else
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    Save();
  end
  else if Key = VK_ESCAPE then
  begin
    //fSearchAndReplace.ClearHighlights();
  end
  else if Key = VK_F3 then
  begin
    if Shift = [ssShift] then
       TextEditor.Find(True)
    else
       TextEditor.Find(False)
  end
  *)
end;

procedure TTextEditorForm2.Editor_CaretChangedPos(Sender: TObject);
begin
  UpdateStatusBarLineColumn();

end;

procedure TTextEditorForm2.Editor_ChangeZoom(Sender: TObject);
begin
  UpdateStatusBar();
end;

procedure TTextEditorForm2.AutoSaveTimerTick(Sender: TObject);
var
  NowTick: QWord;
begin
  if not TextEditor.Modified then
    Exit;
  if not FAutoSaveDirty then
    Exit;

  NowTick := GetTickCount64;

  // save only when no typing is going on
  if (NowTick - FLastEditTick) < QWord(FAutoSaveIdleMs) then
    Exit;

  Save();                  // SaveEditorText() should set Modified := False

  if not TextEditor.Modified then
    FAutoSaveDirty := False;

end;

procedure TTextEditorForm2.UpdateStatusBarLineColumn();
begin
  StatusBar.Panels[0].Text := Format(' Ln: %d, Col: %d', [TextEditor.CaretY, TextEditor.CaretX]);
end;

procedure TTextEditorForm2.UpdateStatusBar();
  function GetZoom(): string;
  var
    V: Integer;
  begin
    V := 100;
    if TextEditor.Editor.OptScaleFont <> 0 then
      V := TextEditor.Editor.OptScaleFont;
    Result := IntToStr(V) + '%';
  end;

begin
  UpdateStatusBarLineColumn();
  //StatusBar.Panels[3].Text := Format('      %s', [GetZoom()]);
  //StatusBar.Panels[4].Text := Format('      %s', [Doc.RealFilePath]);
end;


end.

