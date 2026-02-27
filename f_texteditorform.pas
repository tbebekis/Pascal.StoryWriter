unit f_TextEditorForm;

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
  , ComCtrls
  , ExtCtrls
  , LCLType

  , Tripous.Broadcaster
  , f_PageForm
  , o_TextEditor
  , o_FindAndReplace
  , o_TextStats

  ;

type

  { TTextEditorForm }

  TTextEditorForm = class(TForm)
    StatusBar: TStatusBar;
    ToolBar: TToolBar;
  private
    btnSave: TToolButton;
    btnFind: TToolButton;
    btnSearchForTerm: TToolButton;
    btnShowFolder: TToolButton;

    fFramePage: TPageForm;
    fStats: TTextStats;
    lblTitle: TEdit;
    fIgnoreModifiedCount: Integer;

    FAutoSaveTimer: TTimer;

    FLastEditTick: QWord;
    FAutoSaveDirty: Boolean;
    FAutoSaveIdleMs: Integer;
    fTextEditor: TTextEditor;

    IsHighlighterRegistered: Boolean;
    IsInitialized: Boolean;

    function GetEditorText: string;
    procedure SetEditorText(AValue: string);

    function GetIgnoreModified: Boolean;
    procedure SetIgnoreModified(AValue: Boolean);

    function GetModified: Boolean;
    procedure SetModified(AValue: Boolean);

    function GetTitle: string;
    procedure SetTitle(AValue: string);

    function GetToolBarVisible: Boolean;
    procedure SetToolBarVisible(AValue: Boolean);

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure Editor_Change(Sender: TObject);
    procedure Editor_ModifiedChanged(Sender: TObject);
    procedure Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Editor_CaretChangedPos(Sender: TObject);
    procedure Editor_ChangeZoom(Sender: TObject);
    procedure ToolBar_OnResize(Sender: TObject);

    procedure AutoSaveTimerTick(Sender: TObject);

    procedure FormInitialize();
    procedure FormInitializeAfter();
    procedure PrepareToolBar();

    procedure UpdateStatusBarLineColumn();
    procedure UpdateTextMetrics();
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs);
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure SaveText();
    procedure GlobalSearchForTerm();
    procedure UpdateStatusBar();

    procedure SetHighlightTerm(const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
    procedure RegisterHighlighter(const FilePath: string);

    // ● properties
    property TextEditor: TTextEditor read fTextEditor;

    property Title: string read GetTitle write SetTitle;
    property EditorText : string read GetEditorText write SetEditorText;        // setting does not trigger Modified
    property Modified: Boolean read GetModified write SetModified;              // setting does not trigger Modified
    property ToolBarVisible: Boolean read GetToolBarVisible write SetToolBarVisible;

    property IgnoreModified: Boolean read GetIgnoreModified write SetIgnoreModified;
    property FramePage: TPageForm read fFramePage write fFramePage;

    property Stats: TTextStats read fStats;
  end;



implementation

{$R *.lfm}

uses
   Math
  ,Tripous
  ,Tripous.IconList
  ,o_Consts
  ,o_App
  ,o_Highlighters
  ,o_Filer
  ;


{ TTextEditorForm }

constructor TTextEditorForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BorderStyle := bsNone;
  BorderIcons := [];
  Position := poDesigned;
  ShowInTaskBar := stNever;
  Align := alClient;
  Visible := False;

  fTextEditor := TTextEditor.Create(Self);
  TextEditor.Parent := Self;

  lblTitle := TEdit.Create(ToolBar); // TLabel.Create(ToolBar);
  lblTitle.Parent := ToolBar;
  lblTitle.Font.Bold := True;
  lblTitle.Font.Size := 12;
  lblTitle.ReadOnly := True;
  lblTitle.Color := clForm;

  ToolBar.OnResize := ToolBar_OnResize;
end;

destructor TTextEditorForm.Destroy();
begin
  if IsHighlighterRegistered then
     THighlighters.UnregisterEditor(TextEditor);

  inherited Destroy();
end;

procedure TTextEditorForm.SaveText();
begin
  FramePage.SaveEditorText(Self.TextEditor);
end;

procedure TTextEditorForm.GlobalSearchForTerm();
var
  Term : string;
begin
  Term := UTF8Encode(TextEditor.GetWordAtCaret());
  if Length(Term) > 2 then
  begin
    App.SetGlobalSearchTerm(Term);
  end;
end;

procedure TTextEditorForm.DoShow;
begin
  inherited DoShow;
  if not IsInitialized then
  begin
    FormInitialize();
    IsInitialized := True;
  end;
end;

procedure TTextEditorForm.FormInitialize();
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

  TextEditor.OnKeyDown := Editor_KeyDown;
  TextEditor.OnChange := Editor_Change;
  TextEditor.OnChangeCaretPos := Editor_CaretChangedPos;
  TextEditor.OnChangeZoom := Editor_ChangeZoom;

  TextEditor.SetFocus();

  PrepareToolBar();
  UpdateStatusBar();

  Sys.RunOnce(500 * 3, FormInitializeAfter);
end;

procedure TTextEditorForm.FormInitializeAfter();
begin
  lblTitle.Width := ToolBar.Width - lblTitle.Left;
  //lblTitle.Anchors := [akTop, akLeft, akRight];
end;

procedure TTextEditorForm.RegisterHighlighter(const FilePath: string);
begin
  THighlighters.ApplyToEditor(TextEditor, FilePath);
  TextEditor.Invalidate;
  TextEditor.Update;
  IsHighlighterRegistered := True;
end;

procedure TTextEditorForm.ToolBar_OnResize(Sender: TObject);
begin
  if Assigned(lblTitle) and Assigned(ToolBar) then
    lblTitle.Width := ToolBar.Width - lblTitle.Left;
end;

procedure TTextEditorForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.Wrapable := False;

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnFind := IconList.AddButton(ToolBar, 'PAGE_FIND', 'Find and Replace (Ctrl + F)', AnyClick);
    btnSearchForTerm := IconList.AddButton(ToolBar, 'table_tab_search', 'Search for Term (Ctrl + T or Ctrl + LeftClick)', AnyClick);
    btnSave := IconList.AddButton(ToolBar, 'disk', 'Save (Ctrl + S)', AnyClick);
    //btnShowFolder := IconList.AddButton(ToolBar, 'FOLDER_GO', 'Show in folder', AnyClick);
    //IconList.AddSeparator(ToolBar);
  finally
    ToolBar.Parent := P;
  end;

  ToolBar.Update();
end;

function TTextEditorForm.GetEditorText: string;
begin
  Result := TextEditor.EditorText;
end;

procedure TTextEditorForm.SetEditorText(AValue: string);
begin
  TextEditor.EditorText := AValue;
end;

function TTextEditorForm.GetIgnoreModified: Boolean;
begin
  Result := fIgnoreModifiedCount > 0;
end;

procedure TTextEditorForm.SetIgnoreModified(AValue: Boolean);
begin
  if AValue then
    Inc(fIgnoreModifiedCount)
  else
    Dec(fIgnoreModifiedCount);

  if fIgnoreModifiedCount < 0 then
    fIgnoreModifiedCount := 0;
end;

function TTextEditorForm.GetModified: Boolean;
begin
  Result := TextEditor.Modified;
end;

procedure TTextEditorForm.SetModified(AValue: Boolean);
begin
  TextEditor.Modified := AValue;
end;

function TTextEditorForm.GetTitle: string;
begin
  Result := lblTitle.Caption;
end;

procedure TTextEditorForm.SetTitle(AValue: string);
begin
  lblTitle.Caption := AValue;
end;

function TTextEditorForm.GetToolBarVisible: Boolean;
begin
  Result := ToolBar.Visible
end;

procedure TTextEditorForm.SetToolBarVisible(AValue: Boolean);
begin
   ToolBar.Visible := AValue;
end;

procedure TTextEditorForm.AnyClick(Sender: TObject);
begin
  if btnSave = Sender then
    SaveText()
  else if btnFind = Sender then
    TextEditor.ShowFindAndReplaceDialog()
  //else if btnShowFolder = Sender then
  //  App.DisplayFileExplorer(Doc.RealFilePath)

end;

procedure TTextEditorForm.Editor_Change(Sender: TObject);
begin
  FAutoSaveDirty := True;              // something is written, start "idle countdown"
  FLastEditTick := GetTickCount64;
end;

procedure TTextEditorForm.Editor_ModifiedChanged(Sender: TObject);
begin

end;

procedure TTextEditorForm.Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    SaveText();
  end
end;

procedure TTextEditorForm.Editor_CaretChangedPos(Sender: TObject);
begin
  UpdateStatusBarLineColumn();
end;

procedure TTextEditorForm.Editor_ChangeZoom(Sender: TObject);
begin
  UpdateStatusBar();
end;



procedure TTextEditorForm.AutoSaveTimerTick(Sender: TObject);
var
  NowTick: QWord;
begin
  if not App.Settings.AutoSave then Exit;
  if IgnoreModified then Exit;
  if not Modified then Exit;
  if not FAutoSaveDirty then Exit;
  if not Assigned(FramePage) then Exit;

  NowTick := GetTickCount64;

  // save only when no typing is going on
  if (NowTick - FLastEditTick) < QWord(FAutoSaveIdleMs) then
    Exit;

  SaveText();                  // SaveEditorText() should set Modified := False
  if not Modified then
    FAutoSaveDirty := False;

end;

procedure TTextEditorForm.UpdateStatusBarLineColumn();
begin
  StatusBar.Panels[0].Text := Format(' Ln: %d, Col: %d', [TextEditor.CaretY, TextEditor.CaretX]);
end;

procedure TTextEditorForm.UpdateTextMetrics();
begin
  Stats.Reset();
  TextMetrics.AccumulateStats(Stats, TextEditor.EditorText);
  TextMetrics.FinalizeStats(Stats);
  UpdateStatusBar();
end;

procedure TTextEditorForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekProjectMetricsChanged:
    begin
      UpdateTextMetrics();
    end;
  end;

end;

procedure TTextEditorForm.UpdateStatusBar();
  function GetZoom(): string;
  var
    V: Integer;
  begin
    V := 100;
    if TextEditor.OptScaleFont <> 0 then
      V := TextEditor.OptScaleFont;
    Result := IntToStr(V) + '%';
  end;

begin
  UpdateStatusBarLineColumn();
  //StatusBar.Panels[3].Text := Format('      %s', [GetZoom()]);
  //StatusBar.Panels[4].Text := Format('      %s', [Doc.RealFilePath]);
end;

procedure TTextEditorForm.SetHighlightTerm(const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
begin
  Self.SetFocus();
  Self.SetFocusedControl(TextEditor);
  Application.ProcessMessages();

  Self.TextEditor.FindAndReplace.Options.Clear();
  Self.TextEditor.FindAndReplace.Options.TextToFind := Term;
  Self.TextEditor.FindAndReplace.Options.WholeWord := IsWholeWord;
  Self.TextEditor.FindAndReplace.Options.MatchCase := MatchCase;
  Self.TextEditor.HighlightAll();

  (*
  if Assigned(TM) then
  begin
    EditorForm.TextEditor.SetCaretPos(TM.Column, TM.Line);
    EditorForm.UpdateStatusBar();
    Application.ProcessMessages();
    EditorForm.TextEditor.HighlightAll();
  end;
  *)
end;




end.

