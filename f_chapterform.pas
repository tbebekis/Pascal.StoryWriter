unit f_ChapterForm;

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
  , Tripous.Broadcaster
  , f_PageForm
  , f_TextEditorForm
  , o_Entities
  , o_TextEditor
  ;

type

  { TChapterForm }

  TChapterForm = class(TPageForm)
  private
    Chapter: TChapter;
    frmSynopsis: TTextEditorForm;
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure SaveEditorText(TextEditor: TTextEditor); override;

    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); override;
  end;



implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_Consts
  ;


{ TChapterForm }

constructor TChapterForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmSynopsis := TTextEditorForm.Create(Self);
  frmSynopsis.Parent := Self;
end;

destructor TChapterForm.Destroy();
begin
  inherited Destroy();
end;


procedure TChapterForm.FormInitialize;
begin
  frmSynopsis.Visible := True;

  Self.CloseableByUser := True;

  Chapter := Info as TChapter;

  frmSynopsis.FramePage := Self;
  frmSynopsis.EditorText := Chapter.Synopsis;
  frmSynopsis.Modified := False;

  if frmSynopsis.CanFocus() then
    frmSynopsis.TextEditor.SetFocus();

  TitleChanged();
end;

procedure TChapterForm.FormInitializeAfter();
begin
end;

procedure TChapterForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekItemChanged:               // (TBaseItem(Args.Data));
    begin
      if (Args.Sender <> Self) and ((TBaseItem(Args.Data) = Chapter)) then
        TitleChanged();
    end;
  end;
end;

procedure TChapterForm.TitleChanged();
begin
  TitleText := Chapter.DisplayTitleInProject;
  frmSynopsis.Title := TitleText;
  AdjustTabTitle();
end;

procedure TChapterForm.AdjustTabTitle();
begin
  if frmSynopsis.Modified then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TChapterForm.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
begin

end;

(*
var
  frEditor: TfrTextEditor;
begin
  if not Assigned(LinkItem) then
    Exit;

  frEditor := nil;

  case LinkItem.Place of
    lpSynopsis: frEditor := frmSynopsis;
  end;

  if Assigned(frEditor) then
  begin
    frEditor.SetHighlightTerm(Term, IsWholeWord, MatchCase);
    frEditor.JumpToCharPos(LinkItem.CharPos);
  end;
end;
*)

procedure TChapterForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
begin
  if TextEditor = frmSynopsis.TextEditor then
  begin
    Chapter.Synopsis := frmSynopsis.EditorText;
    Chapter.SaveSynopsis();
    Message := Format('Chapter Synopsis Text saved: %s.', [Chapter.DisplayTitleInProject]);
  end;

  TextEditor.Modified := False;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;




end.

