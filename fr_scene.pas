unit fr_Scene;

{$MODE DELPHI}{$H+}

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
  { TfrScene }
  TfrScene = class(TFramePage)
    frText: TfrTextEditor;
    frSynopsis: TfrTextEditor;
    frTimeline: TfrTextEditor;
    frTextEn: TfrTextEditor;
    Pager: TPageControl;
    Splitter: TSplitter;
    tabText: TTabSheet;
    tabSynopsis: TTabSheet;
    tabTimeline: TTabSheet;
  private
     Scene: TScene;

  protected
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure ShowTabPage(Place: TLinkPlace);
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

{ TfrScene }

procedure TfrScene.ControlInitialize;
begin
  inherited ControlInitialize;

  Self.CloseableByUser := True;
  Pager.ActivePage := tabText;

  Scene := Info as TScene;
  TitleChanged();

  frText.FramePage := Self;
  frTextEn.FramePage := Self;
  frSynopsis.FramePage := Self;
  frTimeline.FramePage := Self;

  frText.EditorText := Scene.Text;
  frTextEn.EditorText := Scene.TextEn;
  frSynopsis.EditorText := Scene.Synopsis;
  frTimeline.EditorText := Scene.Timeline;

  frText.Modified := False;
  frTextEn.Modified := False;
  frSynopsis.Modified := False;
  frTimeline.Modified := False;

  if not App.Settings.EnglishVisible then
  begin
    frTextEn.Visible := False;
    Splitter.Visible := False;
  end;

  Pager.ActivePage := tabText;
  if frText.CanFocus() then
       frText.Editor.SetFocus();
end;

procedure TfrScene.ControlInitializeAfter();
begin
  frText.Width := (Self.ClientWidth - Splitter.Width) div 2;
end;

procedure TfrScene.OnBroadcasterEvent(Args: TBroadcasterArgs);
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

procedure TfrScene.TitleChanged();
begin
  TitleText := Scene.DisplayTitleInProject;
  frText.Title := TitleText;
  frTextEn.Title := TitleText;
  frSynopsis.Title := TitleText;
  frTimeline.Title := TitleText;
  AdjustTabTitle();
end;

procedure TfrScene.AdjustTabTitle();
begin
  if frText.Modified or frTextEn.Modified or frSynopsis.Modified or frTimeline.Modified then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;

  if frText.Modified or frTextEn.Modified then
     tabText.Caption := 'Text*'
  else
     tabText.Caption := 'Text';

  if frSynopsis.Modified  then
     tabSynopsis.Caption := 'Synopsis*'
  else
     tabSynopsis.Caption := 'Synopsis';

  if frTimeline.Modified  then
     tabTimeline.Caption := 'Timeline*'
  else
     tabTimeline.Caption := 'Timeline';

end;



procedure TfrScene.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
var
  frEditor: TfrTextEditor;
begin
  if not Assigned(LinkItem) then
    Exit;

  frEditor := nil;

  case LinkItem.Place of
    lpText: frEditor := frText;
    lpTextEn: if App.Settings.EnglishVisible then frEditor := frTextEn;
    lpSynopsis: frEditor := frSynopsis;
    lpTimeline: frEditor := frTimeline;
  end;

  if Assigned(frEditor) then
  begin
    frEditor.SetHighlightTerm(Term, IsWholeWord, MatchCase);
    frEditor.JumpToCharPos(LinkItem.CharPos);
  end;
end;

procedure TfrScene.SaveEditorText(TextEditor: TfrTextEditor);
var
  Message: string;
begin
  if TextEditor = frText then
  begin
    Scene.Text := frText.EditorText;
    Scene.SaveText();
    Message := Format('Scene Text saved: %s.', [Scene.DisplayTitleInProject]);
  end else if TextEditor = frTextEn then
  begin
    Scene.TextEn := frTextEn.EditorText;
    Scene.SaveTextEn();
    Message := Format('Scene English Text saved: %s.', [Scene.DisplayTitleInProject]);
  end else if TextEditor = frSynopsis then
  begin
    Scene.Synopsis := frSynopsis.EditorText;
    Scene.SaveSynopsis();
    Message := Format('Scene Synopsis Text saved: %s.', [Scene.DisplayTitleInProject]);
  end else
  begin
    Scene.Timeline := frTimeline.EditorText;
    Scene.SaveTimeline();
    Message := Format('Scene Timeline Text saved: %s.', [Scene.DisplayTitleInProject]);
  end;

  TextEditor.Modified := False;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;

procedure TfrScene.ShowTabPage(Place: TLinkPlace);
begin
  case Place of
    lpSynopsis: Pager.ActivePage := tabSynopsis;
    lpTimeline: Pager.ActivePage := tabTimeline;
  else
    Pager.ActivePage := tabText;
  end;
end;



end.

