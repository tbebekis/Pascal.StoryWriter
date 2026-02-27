unit f_NoteForm;

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

  { TNoteForm }

  TNoteForm = class(TPageForm)
  private
    frmText: TTextEditorForm;
    Note: TNote;
  protected
    procedure FormInitialize(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

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

{ TNoteForm }

constructor TNoteForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := Self;
end;

destructor TNoteForm.Destroy();
begin
  inherited Destroy();
end;

procedure TNoteForm.FormInitialize;
begin
  frmText.Visible := True;

  Self.CloseableByUser := True;

  Note := TNote(Info);

  frmText.FramePage := Self;
  frmText.EditorText := Note.Text;
  frmText.Modified := False;

  if frmText.CanFocus() then
       frmText.TextEditor.SetFocus();

  TitleChanged();
end;

procedure TNoteForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekItemChanged: if (Args.Data = Note) and (Args.Sender <> Self) then
         TitleChanged();
  end;
end;

procedure TNoteForm.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
begin

end;
(*
begin
  if not Assigned(LinkItem) then
    Exit;

  frmText.SetHighlightTerm(Term, IsWholeWord, MatchCase);
  frmText.JumpToCharPos(LinkItem.CharPos);
end;
*)

procedure TNoteForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
begin
  Note.Text := TextEditor.EditorText;
  Note.Save();
  TextEditor.Modified := false;

  Message := Format('Note saved: %s', [Note.Title]);
  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;


end.

