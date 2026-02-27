unit f_StoryForm;

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

  { TStoryForm }

  TStoryForm = class(TPageForm)
  private
    frmSynopsis: TTextEditorForm;
    Story: TStory;
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); override;
    { editor handler }
    procedure SaveEditorText(TextEditor: TTextEditor); override;
  end;


implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_Consts
  ;

{ TStoryForm }

constructor TStoryForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmSynopsis := TTextEditorForm.Create(Self);
  frmSynopsis.Parent := Self;
end;

destructor TStoryForm.Destroy();
begin
  inherited Destroy();
end;

procedure TStoryForm.FormInitialize;
begin
  frmSynopsis.Visible := True;

  Self.CloseableByUser := True;

  Story := Info as TStory;

  frmSynopsis.FramePage := Self;
  frmSynopsis.EditorText := Story.Synopsis;
  frmSynopsis.Modified := False;

  if frmSynopsis.CanFocus() then
    frmSynopsis.TextEditor.SetFocus();

  TitleChanged();
end;

procedure TStoryForm.FormInitializeAfter();
begin
end;

procedure TStoryForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
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

procedure TStoryForm.TitleChanged();
begin
  TitleText := Story.DisplayTitleInProject;
  frmSynopsis.Title := TitleText;
  AdjustTabTitle();
end;

procedure TStoryForm.AdjustTabTitle();
begin
  if frmSynopsis.Modified then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TStoryForm.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
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

procedure TStoryForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
begin
  if TextEditor = frmSynopsis.TextEditor then
  begin
    Story.Synopsis := frmSynopsis.EditorText;
    Story.SaveSynopsis();
    Message := Format('Story Synopsis Text saved: %s.', [Story.DisplayTitleInProject]);
    LogBox.AppendLine(Message);
  end;

  TextEditor.Modified := False;
  AdjustTabTitle();
end;

end.

