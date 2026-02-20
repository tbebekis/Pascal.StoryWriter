unit fr_Story;

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

  { TfrStory }

  TfrStory = class(TFramePage)
    frSynopsis: TfrTextEditor;
  private
    Story: TStory;

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

{ TfrStory }



procedure TfrStory.ControlInitialize;
begin
  inherited ControlInitialize;

  Self.CloseableByUser := True;

  Story := Info as TStory;
  TitleChanged();

  frSynopsis.FramePage := Self;
  frSynopsis.EditorText := Story.Synopsis;
  frSynopsis.Modified := False;

  if frSynopsis.CanFocus() then
    frSynopsis.Editor.SetFocus();
end;

procedure TfrStory.ControlInitializeAfter();
begin
end;

procedure TfrStory.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekItemChanged:               // (TBaseItem(Args.Data));
    begin
      if (Args.Sender <> Self) and ((TBaseItem(Args.Data) = Story)) then
        TitleChanged();
    end;
  end;
end;

procedure TfrStory.TitleChanged();
begin
  TitleText := Story.DisplayTitleInProject;
  frSynopsis.Title := TitleText;
  AdjustTabTitle();
end;

procedure TfrStory.AdjustTabTitle();
begin
  if frSynopsis.Modified then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TfrStory.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
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

procedure TfrStory.SaveEditorText(TextEditor: TfrTextEditor);
var
  Message: string;
begin
  if TextEditor = frSynopsis then
  begin
    Story.Synopsis := frSynopsis.EditorText;
    Story.SaveSynopsis();
    Message := Format('Story Synopsis Text saved: %s.', [Story.DisplayTitleInProject]);
    LogBox.AppendLine(Message);
  end;

  TextEditor.Modified := False;
  AdjustTabTitle();
end;



end.

