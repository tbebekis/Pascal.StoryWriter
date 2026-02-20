unit fr_Component;

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
  , fr_FramePage
  , fr_TextEditor
  , o_Entities
  ;

type

  { TfrComponent }

  TfrComponent = class(TFramePage)
    frText: TfrTextEditor;
    frTextEn: TfrTextEditor;
    Splitter: TSplitter;
  private
    Comp: TSWComponent;

    // ● event handler
    procedure AnyClick(Sender: TObject);
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
  ,o_App
  ;

{ TfrComponent }

procedure TfrComponent.ControlInitialize;
begin
  inherited ControlInitialize;

  Self.CloseableByUser := True;

  Comp := Info as TSWComponent;
  TitleChanged();

  frText.FramePage := Self;
  frTextEn.FramePage := Self;

  frText.EditorText := Comp.Text;
  frTextEn.EditorText := Comp.TextEn;

  frText.Modified := False;
  frTextEn.Modified := False;

  if not App.Settings.EnglishVisible then
  begin
    frTextEn.Visible := False;
    Splitter.Visible := False;
  end;

  if frText.CanFocus() then
       frText.Editor.SetFocus();
end;

procedure TfrComponent.ControlInitializeAfter();
begin
  frText.Width := (Self.ClientWidth - Splitter.Width) div 2;
end;

procedure TfrComponent.TitleChanged();
begin
  TitleText := Comp.DisplayTitleInProject;
  frText.Title := TitleText;
  frTextEn.Title := TitleText;
  AdjustTabTitle();
end;

procedure TfrComponent.AdjustTabTitle();
begin
  if frText.Modified or frTextEn.Modified   then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;


end;

procedure TfrComponent.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
var
  frEditor: TfrTextEditor;
begin
  if not Assigned(LinkItem) then
    Exit;

  frEditor := nil;

  case LinkItem.Place of
    lpText: frEditor := frText;
    lpTextEn: if App.Settings.EnglishVisible then frEditor := frTextEn;
  end;

  if Assigned(frEditor) then
  begin
    frEditor.SetHighlightTerm(Term, IsWholeWord, MatchCase);
    frEditor.JumpToCharPos(LinkItem.CharPos);
  end;
end;



procedure TfrComponent.SaveEditorText(TextEditor: TfrTextEditor);
var
  Message: string;
begin
  if TextEditor = frText then
  begin
    Comp.Text := frText.EditorText;
    Comp.Save();
    Message := Format('Component Text saved: %s.', [Comp.DisplayTitleInProject]);
  end else if TextEditor = frTextEn then
  begin
    Comp.TextEn := frTextEn.EditorText;
    Comp.Save();
    Message := Format('Component English Text saved: %s.', [Comp.DisplayTitleInProject]);
  end;

  TextEditor.Modified := False;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;

procedure TfrComponent.AnyClick(Sender: TObject);
begin
  // TODO:  TfrComponent.AnyClick
end;

end.

