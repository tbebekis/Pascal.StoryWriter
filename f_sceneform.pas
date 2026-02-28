unit f_SceneForm;

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
  , Tripous.Broadcaster
  , f_PageForm
  , f_TextEditorForm
  , o_TextEditor
  , o_Entities
  ;

type

  { TSceneForm }

  TSceneForm = class(TPageForm)
    Pager: TPageControl;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    Splitter: TSplitter;
    tabText: TTabSheet;
    tabSynopsis: TTabSheet;
    tabTimeline: TTabSheet;
  private
    frmText: TTextEditorForm;
    frmTextEn: TTextEditorForm;
    frmSynopsis: TTextEditorForm;
    frmTimeline: TTextEditorForm;

     Scene: TScene;
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure ShowTabPage(Place: TLinkPlace);
    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); override;

    { editor handler }
    procedure SaveEditorText(TextEditor: TTextEditor); override;
    procedure ShowEditorFile(TextEditor: TTextEditor); override;
  end;



implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_Consts
  ,o_App
  ;

{ TSceneForm }

constructor TSceneForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := pnlLeft;

  frmTextEn := TTextEditorForm.Create(Self);
  frmTextEn.Parent := pnlRight;

  frmSynopsis := TTextEditorForm.Create(Self);
  frmSynopsis.Parent := tabSynopsis;

  frmTimeline := TTextEditorForm.Create(Self);
  frmTimeline.Parent := tabTimeline;
end;

destructor TSceneForm.Destroy();
begin
  inherited Destroy();
end;

procedure TSceneForm.FormInitialize;
begin
  if not App.Settings.EnglishVisible then
  begin
    pnlRight.Visible := False;
    Splitter.Visible := False;
  end;

  frmText.Visible := True;
  frmTextEn.Visible := True;
  frmSynopsis.Visible := True;
  frmTimeline.Visible := True;

  Self.CloseableByUser := True;
  Pager.ActivePage := tabText;

  Scene := Info as TScene;

  frmText.FramePage := Self;
  frmTextEn.FramePage := Self;
  frmSynopsis.FramePage := Self;
  frmTimeline.FramePage := Self;

  frmText.EditorText := Scene.Text;
  frmTextEn.EditorText := Scene.TextEn;
  frmSynopsis.EditorText := Scene.Synopsis;
  frmTimeline.EditorText := Scene.Timeline;

  frmText.Modified := False;
  frmTextEn.Modified := False;
  frmSynopsis.Modified := False;
  frmTimeline.Modified := False;

  Pager.ActivePage := tabText;
  if frmText.CanFocus() then
       frmText.TextEditor.SetFocus();

  TitleChanged();
end;

procedure TSceneForm.FormInitializeAfter();
begin
  if App.Settings.EnglishVisible then
    pnlLeft.Width := (Self.ClientWidth - Splitter.Width) div 2;
end;

procedure TSceneForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekItemChanged:               // (TBaseItem(Args.Data));
    begin
      if (Args.Sender <> Self) and ((TBaseItem(Args.Data) = Scene)) then
        TitleChanged();
    end;
  end;
end;

procedure TSceneForm.TitleChanged();
begin
  TitleText := Scene.DisplayTitleInProject;
  frmText.Title := TitleText;
  frmTextEn.Title := TitleText;
  frmSynopsis.Title := TitleText;
  frmTimeline.Title := TitleText;
  AdjustTabTitle();
end;

procedure TSceneForm.AdjustTabTitle();
begin
  if frmText.Modified or frmTextEn.Modified or frmSynopsis.Modified or frmTimeline.Modified then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;

  if frmText.Modified or frmTextEn.Modified then
     tabText.Caption := 'Text*'
  else
     tabText.Caption := 'Text';

  if frmSynopsis.Modified  then
     tabSynopsis.Caption := 'Synopsis*'
  else
     tabSynopsis.Caption := 'Synopsis';

  if frmTimeline.Modified  then
     tabTimeline.Caption := 'Timeline*'
  else
     tabTimeline.Caption := 'Timeline';

end;

procedure TSceneForm.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
var
  EditorForm: TTextEditorForm;
begin
  if not Assigned(LinkItem) then
    Exit;

  EditorForm := nil;

  case LinkItem.Place of
    lpText: EditorForm := frmText;
    lpTextEn: if App.Settings.EnglishVisible then EditorForm := frmTextEn;
    lpSynopsis: EditorForm := frmSynopsis;
    lpTimeline: EditorForm := frmTimeline;
  end;

  if Assigned(EditorForm) then
  begin
    EditorForm.SetHighlightTerm(Term, LinkItem.Line, LinkItem.Column, IsWholeWord, MatchCase);

  end;

end;



procedure TSceneForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
begin
  if TextEditor = frmText.TextEditor then
  begin
    Scene.Text := frmText.EditorText;
    Scene.SaveText();
    Message := Format('Scene Text saved: %s.', [Scene.DisplayTitleInProject]);
  end else if TextEditor = frmTextEn.TextEditor then
  begin
    Scene.TextEn := frmTextEn.EditorText;
    Scene.SaveTextEn();
    Message := Format('Scene English Text saved: %s.', [Scene.DisplayTitleInProject]);
  end else if TextEditor = frmSynopsis.TextEditor then
  begin
    Scene.Synopsis := frmSynopsis.EditorText;
    Scene.SaveSynopsis();
    Message := Format('Scene Synopsis Text saved: %s.', [Scene.DisplayTitleInProject]);
  end else
  begin
    Scene.Timeline := frmTimeline.EditorText;
    Scene.SaveTimeline();
    Message := Format('Scene Timeline Text saved: %s.', [Scene.DisplayTitleInProject]);
  end;

  TextEditor.Modified := False;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;

procedure TSceneForm.ShowEditorFile(TextEditor: TTextEditor);
begin
  if TextEditor = frmText.TextEditor then
  begin
    if FileExists(Scene.TextFilePath) then
        App.DisplayFileExplorer(Scene.TextFilePath);
  end else if TextEditor = frmTextEn.TextEditor then
  begin
    if FileExists(Scene.TextEnFilePath) then
        App.DisplayFileExplorer(Scene.TextEnFilePath);
  end else if TextEditor = frmSynopsis.TextEditor then
  begin
    if FileExists(Scene.SynopsisFilePath) then
        App.DisplayFileExplorer(Scene.SynopsisFilePath);
  end else
  begin
    if FileExists(Scene.TimelineFilePath) then
        App.DisplayFileExplorer(Scene.TimelineFilePath);
  end;

end;

procedure TSceneForm.ShowTabPage(Place: TLinkPlace);
begin
  case Place of
    lpSynopsis: Pager.ActivePage := tabSynopsis;
    lpTimeline: Pager.ActivePage := tabTimeline;
  else
    Pager.ActivePage := tabText;
  end;
end;


end.

