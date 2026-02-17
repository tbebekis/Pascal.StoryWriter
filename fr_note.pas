unit fr_Note;

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
  , fr_FramePage
  , fr_TextEditor
  , o_Entities
  ;

type

  { TfrNote }

  TfrNote = class(TFramePage)
    frText: TfrTextEditor;
  private
    Note: TNote;
    // ● event handler
    procedure AnyClick(Sender: TObject);
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
  ,o_App
  ;

{ TfrNote }



procedure TfrNote.ControlInitialize;
begin
  inherited ControlInitialize;

  Self.CloseableByUser := True;

  Note := TNote(Info);
  TitleChanged();

  frText.FramePage := Self;
  frText.EditorText := Note.Text;
  frText.Modified := False;

  if frText.CanFocus() then
       frText.Editor.SetFocus();
end;

procedure TfrNote.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
end;

procedure TfrNote.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekItemChanged: if (Args.Data = Note) and (Args.Sender <> Self) then
         TitleChanged();
  end;
end;

procedure TfrNote.TitleChanged();
begin
  inherited TitleChanged();
end;

procedure TfrNote.AdjustTabTitle();
begin
  inherited AdjustTabTitle();
end;

procedure TfrNote.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
begin
  if not Assigned(LinkItem) then
    Exit;

  frText.SetHighlightTerm(Term, IsWholeWord, MatchCase);
  frText.JumpToCharPos(LinkItem.CharPos);
end;

procedure TfrNote.SaveEditorText(TextEditor: TfrTextEditor);
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

procedure TfrNote.AnyClick(Sender: TObject);
begin

end;



end.

