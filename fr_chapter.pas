unit fr_Chapter;

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
  , Menus
  , SynEdit
  , Tripous.Broadcaster
  , fr_TextEditor
  , fr_FramePage
  , o_Entities
  ;

type

  { TfrChapter }

  TfrChapter = class(TFramePage)
    frSynopsis: TfrTextEditor;
  private
    Chapter: TChapter;


  protected
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); override;

    { editor handler }
    procedure SaveEditorText(TextEditor: TfrTextEditor); override;
  end;

implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_Consts
  ;

{ TfrChapter }

procedure TfrChapter.ControlInitialize;
begin
  inherited ControlInitialize;

  Self.CloseableByUser := True;

  Chapter := Info as TChapter;
  TitleChanged();

  frSynopsis.FramePage := Self;
  frSynopsis.EditorText := Chapter.Synopsis;
  frSynopsis.Modified := False;

  if frSynopsis.CanFocus() then
    frSynopsis.Editor.SetFocus();
end;

procedure TfrChapter.ControlInitializeAfter();
begin
end;

procedure TfrChapter.OnBroadcasterEvent(Args: TBroadcasterArgs);
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

procedure TfrChapter.TitleChanged();
begin
  TitleText := Chapter.DisplayTitleInProject;
  frSynopsis.Title := TitleText;
  AdjustTabTitle();
end;

procedure TfrChapter.AdjustTabTitle();
begin
  if frSynopsis.Modified then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TfrChapter.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
var
  frEditor: TfrTextEditor;
begin
  if not Assigned(LinkItem) then
    Exit;

  frEditor := nil;

  case LinkItem.Place of
    lpSynopsis: frEditor := frSynopsis;
  end;

  if Assigned(frEditor) then
  begin
    frEditor.SetHighlightTerm(Term, IsWholeWord, MatchCase);
    frEditor.JumpToCharPos(LinkItem.CharPos);
  end;
end;

procedure TfrChapter.SaveEditorText(TextEditor: TfrTextEditor);
var
  Message: string;
begin
  if TextEditor = frSynopsis then
  begin
    Chapter.Synopsis := frSynopsis.EditorText;
    Chapter.SaveSynopsis();
    Message := Format('Chapter Synopsis Text saved: %s.', [Chapter.DisplayTitleInProject]);
  end;

  TextEditor.Modified := False;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;







end.

