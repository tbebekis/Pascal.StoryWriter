unit f_ComponentForm;

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

  { TComponentForm }

  TComponentForm = class(TPageForm)
    pnlRight: TPanel;
    pnlLeft: TPanel;
    Splitter: TSplitter;
  private
    frmText: TTextEditorForm;
    frmTextEn: TTextEditorForm;

    Comp: TSWComponent;

  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); override;

    { editor handler }
    procedure SaveEditorText(TextEditor: TTextEditor); override;
    procedure ShowEditorFile(TextEditor: TTextEditor); override;
  end;


implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_App

  ;

{ TComponentForm }

constructor TComponentForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := pnlLeft;

  frmTextEn := TTextEditorForm.Create(Self);
  frmTextEn.Parent := pnlRight;
end;

destructor TComponentForm.Destroy();
begin
  inherited Destroy();
end;

procedure TComponentForm.FormInitialize;
begin
  if not App.Settings.EnglishVisible then
  begin
    pnlRight.Visible := False;
    Splitter.Visible := False;
  end;

  frmText.Visible := True;
  frmTextEn.Visible := True;

  Self.CloseableByUser := True;

  Comp := Info as TSWComponent;

  frmText.FramePage := Self;
  frmTextEn.FramePage := Self;

  frmText.EditorText := Comp.Text;
  frmTextEn.EditorText := Comp.TextEn;

  frmText.Modified := False;
  frmTextEn.Modified := False;

  if frmText.CanFocus() then
       frmText.TextEditor.SetFocus();

  TitleChanged();


  if App.Settings.UseHighlighters then
  begin
    frmText.RegisterHighlighter('fake.md');
  end;

end;

procedure TComponentForm.FormInitializeAfter();
begin
  frmText.Width := (Self.ClientWidth - Splitter.Width) div 2;
end;

procedure TComponentForm.TitleChanged();
begin
  TitleText := Comp.DisplayTitleInProject;
  frmText.Title := TitleText;
  frmTextEn.Title := TitleText;
  AdjustTabTitle();
end;

procedure TComponentForm.AdjustTabTitle();
begin
  if frmText.Modified or frmTextEn.Modified   then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TComponentForm.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
var
  EditorForm: TTextEditorForm;
begin
  if not Assigned(LinkItem) then
    Exit;

  EditorForm := nil;

  case LinkItem.Place of
    lpText: EditorForm := frmText;
    lpTextEn: if App.Settings.EnglishVisible then EditorForm := frmTextEn;
  end;

  if Assigned(EditorForm) then
  begin
    EditorForm.SetHighlightTerm(Term, LinkItem.Line, LinkItem.Column, IsWholeWord, MatchCase);
  end;
end;


procedure TComponentForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
begin
  if TextEditor = frmText.TextEditor then
  begin
    Comp.Text := frmText.EditorText;
    Comp.Save();
    Message := Format('Component Text saved: %s.', [Comp.DisplayTitleInProject]);
  end else if TextEditor = frmTextEn.TextEditor then
  begin
    Comp.TextEn := frmTextEn.EditorText;
    Comp.Save();
    Message := Format('Component English Text saved: %s.', [Comp.DisplayTitleInProject]);
  end;

  TextEditor.Modified := False;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;

procedure TComponentForm.ShowEditorFile(TextEditor: TTextEditor);
begin
  if TextEditor = frmText.TextEditor then
  begin
    if FileExists(Comp.TextFilePath) then
        App.DisplayFileExplorer(Comp.TextFilePath);
  end else if TextEditor = frmTextEn.TextEditor then
  begin
    if FileExists(Comp.TextFilePathEn) then
        App.DisplayFileExplorer(Comp.TextFilePathEn);
  end;

end;


end.

