unit fr_TextEditor;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , StdCtrls
  , ComCtrls
  , ExtCtrls
  , Graphics
  , LCLType
  , SynEdit
  , SynEditTypes
  , SynEditWrappedView
  , SynEditSearch
  , SynEditMarkupHighAll
  , LCLProc

  ,o_SearchAndReplace
  ;

type
  TfrTextEditor = class;


  { TfrTextEditor }
  TfrTextEditor = class(TFrame)
    StatusBar: TStatusBar;
    Editor: TSynEdit;
    ToolBar: TToolBar;
  private
    btnFind: TToolButton;
    btnSearchForTerm: TToolButton;
    btnSave : TToolButton;

    fSearchAndReplace: TSearchAndReplace;
    fFramePage: TFrame;
    lblTitle: TLabel;

    FWrapPlugin: TLazSynEditLineWrapPlugin;
    fIgnoreModifiedCount: Integer;

    FAutoSaveTimer: TTimer;
    FLastEditTick: QWord;
    FAutoSaveDirty: Boolean;
    FAutoSaveIdleMs: Integer;

    FMarkup: TSynEditMarkupHighlightAll;

    procedure EditorChange(Sender: TObject);
    procedure AutoSaveTimerTick(Sender: TObject);

    function GetEditorText: string;
    function GetIgnoreModified: Boolean;
    function GetModified: Boolean;
    function GetTitle: string;
    function GetToolBarVisible: Boolean;
    procedure InitWordWrap(Data: PtrInt);
    procedure SetEditorText(AValue: string);
    procedure SetIgnoreModified(AValue: Boolean);
    procedure SetModified(AValue: Boolean);
    procedure SetTitle(AValue: string);
    procedure SetToolBarVisible(AValue: Boolean);

    procedure AnyClick(Sender: TObject);
    procedure EditorOnStatusChaned(Sender: TObject; Changes: TSynStatusChanges);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    procedure PrepareToolBar();
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure SaveText();
    procedure GlobalSearchForTerm();


    procedure SetHighlightTerm(const Term: string; WholeWord, MatchCase: Boolean);
    procedure JumpToCharPos(ACharPos: Integer);

    // ● toolbar
    function AddButton(const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
    function AddSeparator(): TToolButton;

(*
TextToFind: string;
ReplaceWith: string;
MatchCase: Boolean;
WholeWord: Boolean;
*)
    // ● find

    property Title: string read GetTitle write SetTitle;
    property EditorText : string read GetEditorText write SetEditorText;        // setting does not trigger Modified
    property Modified: Boolean read GetModified write SetModified;              // setting does not trigger Modified
    property ToolBarVisible: Boolean read GetToolBarVisible write SetToolBarVisible;

    property IgnoreModified: Boolean read GetIgnoreModified write SetIgnoreModified;
    property FramePage: TFrame read fFramePage write fFramePage;
    property FindReplaceOptions : TSearchAndReplace read fSearchAndReplace write fSearchAndReplace;
  end;



implementation

{$R *.lfm}

uses
   Tripous.IconList
  , fr_FramePage
  , o_App
  ;



{ TfrTextEditor }

constructor TfrTextEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  IgnoreModified := True;
  try
    PrepareToolBar();

    FindReplaceOptions := TSearchAndReplace.Create(Editor);


    FAutoSaveIdleMs := 1000 * 3;
    FAutoSaveDirty := False;
    FLastEditTick := GetTickCount64;

    //Editor.ExtraLineSpacing := 2;
    Editor.ScrollBars := ssVertical; // no ssBoth

    Editor.Gutter.Visible := False;
    Editor.RightEdge := 0;

    Editor.OnKeyDown := EditorKeyDown;
    Editor.OnChange := EditorChange;
    Editor.OnStatusChange := EditorOnStatusChaned;

    { auto-save }
    if (App.Settings.AutoSave) then
    begin
      FAutoSaveTimer := TTimer.Create(Self);
      FAutoSaveTimer.Enabled := False;
      FAutoSaveTimer.OnTimer := AutoSaveTimerTick;

      FAutoSaveTimer.Interval := App.Settings.AutoSaveSecondsInterval * 1000;
      FAutoSaveTimer.Enabled := App.Settings.AutoSave;
    end;

    Application.QueueAsyncCall(InitWordWrap, 0);

  finally
    IgnoreModified := False;
  end;

end;

destructor TfrTextEditor.Destroy();
begin
  FreeAndNil(FAutoSaveTimer);
  inherited Destroy();
end;

procedure TfrTextEditor.SaveText();
begin
  (FramePage as TFramePage).SaveEditorText(Self);
end;

procedure TfrTextEditor.GlobalSearchForTerm();
begin
  // TODO: TfrTextEditor.GlobalSearchForTerm(
end;

procedure TfrTextEditor.SetHighlightTerm(const Term: string; WholeWord, MatchCase: Boolean);
var
  Opt: TSynSearchOptions;
begin
  if FMarkup = nil then
  begin
    FMarkup := TSynEditMarkupHighlightAll.Create(Editor);
    Editor.MarkupManager.AddMarkUp(FMarkup);
  end;

  if Term = '' then
  begin
    FMarkup.SearchString := '';
    Editor.Invalidate;
    Exit;
  end;

  Opt := [];
  if WholeWord then
    Include(Opt, ssoWholeWord);
  if MatchCase then
    Include(Opt, ssoMatchCase);

  FMarkup.SearchOptions := Opt;
  FMarkup.SearchString := Term;

  Editor.Invalidate;
end;

procedure TfrTextEditor.JumpToCharPos(ACharPos: Integer);

  function SynCharPosToCaretXY(ACharPos0: Integer): TPoint;
  var
    i: Integer;
    ULine: UnicodeString;
    L: Integer;
    Rem: Integer;
  begin
    Result := Point(1, 1);

    if (Editor = nil) or (ACharPos0 < 0) then
      Exit;

    Rem := ACharPos0;

    for i := 0 to Editor.Lines.Count - 1 do
    begin
      ULine := UTF8Decode(Editor.Lines[i]);
      L := Length(ULine);

      if Rem <= L then
      begin
        Result.Y := i + 1;      // 1-based line
        Result.X := Rem + 1;    // 1-based column
        Exit;
      end;

      // πέρασε τη γραμμή + 1 char για newline
      Dec(Rem, L + 1);
    end;

    // αν βγήκαμε εκτός, πήγαινε τέλος
    Result.Y := Editor.Lines.Count;
    if Result.Y < 1 then Result.Y := 1;

    ULine := UTF8Decode(Editor.Lines[Result.Y - 1]);
    Result.X := Length(ULine) + 1;
  end;

var
  P: TPoint;
begin

  P := SynCharPosToCaretXY(ACharPos);
  Editor.CaretY := P.Y;
  Editor.CaretX := P.X;
  Editor.EnsureCursorPosVisible;
  Editor.SetFocus;
end;

function TfrTextEditor.AddButton(const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
begin
  Result := IconList.AddButton(ToolBar, AIconName, AHint, AOnClick);
end;

function TfrTextEditor.AddSeparator(): TToolButton;
begin
  Result := IconList.AddSeparator(ToolBar);
end;

procedure TfrTextEditor.InitWordWrap(Data: PtrInt);
begin
  if FWrapPlugin = nil then
  begin
    FWrapPlugin := TLazSynEditLineWrapPlugin.Create(Editor);       // owner=Editor
    //FWrapPlugin.Editor := Editor;                                // no - raises exception
    FWrapPlugin.CaretWrapPos := wcpEOL;                            // or wcpBOL
  end;
end;

procedure TfrTextEditor.EditorChange(Sender: TObject);
begin
  if not App.Settings.AutoSave then Exit;
  if IgnoreModified then Exit;

  FAutoSaveDirty := True;              // something is written, start "idle countdown"
  FLastEditTick := GetTickCount64;
end;

procedure TfrTextEditor.AutoSaveTimerTick(Sender: TObject);
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

function TfrTextEditor.GetEditorText: string;
begin
  Result := Editor.Text;
end;

procedure TfrTextEditor.SetEditorText(AValue: string);
var
  P: TPoint;
begin
  IgnoreModified := True;
  try
    P.X := 0; P.Y:= 1;
    Editor.Text := AValue;
    Editor.CaretXY := P;
  finally
    IgnoreModified := False;
  end;
end;

function TfrTextEditor.GetIgnoreModified: Boolean;
begin
  Result := fIgnoreModifiedCount > 0;
end;

procedure TfrTextEditor.SetIgnoreModified(AValue: Boolean);
begin
  if AValue then
    Inc(fIgnoreModifiedCount)
  else
    Dec(fIgnoreModifiedCount);

  if fIgnoreModifiedCount < 0 then
    fIgnoreModifiedCount := 0;
end;

function TfrTextEditor.GetModified: Boolean;
begin
  Result := Editor.Modified;
end;

function TfrTextEditor.GetTitle: string;
begin
  Result := lblTitle.Caption;
end;

function TfrTextEditor.GetToolBarVisible: Boolean;
begin
  Result := ToolBar.Visible;
end;

procedure TfrTextEditor.SetModified(AValue: Boolean);
begin
  IgnoreModified := True;
  try
    Editor.Modified := AValue;
  finally
    IgnoreModified := False;
  end;
end;

procedure TfrTextEditor.SetTitle(AValue: string);
begin
  lblTitle.Caption := AValue;
end;

procedure TfrTextEditor.SetToolBarVisible(AValue: Boolean);
begin
  ToolBar.Visible := AValue;
end;

procedure TfrTextEditor.AnyClick(Sender: TObject);
begin
  if btnFind = Sender then
     fSearchAndReplace.ShowFindDialog()
  else if btnSave = Sender then
    SaveText()
  else if btnSearchForTerm = Sender then
    GlobalSearchForTerm();
end;

procedure TfrTextEditor.EditorOnStatusChaned(Sender: TObject; Changes: TSynStatusChanges);
begin
  if (scModified in Changes) and (not IgnoreModified) and Assigned(FramePage) then
     (FramePage as TFramePage).EditorModifiedChanged(Self);
end;

procedure TfrTextEditor.PrepareToolBar();
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  btnFind := AddButton('page_find', 'Find and Replace (Ctrl + F)', AnyClick);
  btnSearchForTerm := AddButton('table_tab_search', 'Search for Term (Ctrl + T or Ctrl + LeftClick)', AnyClick);
  btnSave := AddButton('disk', 'Save (Ctrl + S)', AnyClick);
  AddSeparator();

  lblTitle := TLabel.Create(ToolBar);
  lblTitle.AutoSize:= True;
  lblTitle.Parent := ToolBar;
  lblTitle.Font.Bold := True;
  lblTitle.Font.Size := 14;
  lblTitle.Caption:= 'Here goes the title of the item';
end;
procedure TfrTextEditor.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_F) then
  begin
    Key := 0;
    fSearchAndReplace.ShowFindDialog();
  end
  else
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    SaveText();
  end
  else if Key = VK_ESCAPE then
  begin
    fSearchAndReplace.ClearHighlights();
  end
  else if Key = VK_F3 then
  begin
    if Shift = [ssShift] then
       fSearchAndReplace.FindPrevious()
    else
        fSearchAndReplace.FindNext();
  end;
end;




end.

