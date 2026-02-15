unit f_mainform;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , FileUtil
  , Forms
  , Controls
  , Graphics
  //, StdCtrls
  , Dialogs
  , Menus
  , DBGrids
  , ComCtrls
  , TypInfo
  , Variants

  ,LazFileUtils
  ,LResources, ExtCtrls, StdCtrls
  ,Tripous
  ,Tripous.Forms.PagerHandler

  ;

type

  { TMainForm }

  TMainForm = class(TForm)
    edtLog: TMemo;
    pagerContent: TPageControl;
    pagerSideBar: TPageControl;
    pnlContent: TPanel;
    splitMain: TSplitter;
    splitContent: TSplitter;
    StatusBar: TStatusBar;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    ToolBar: TToolBar;
  public const
    STitle = 'Story Writer';
  private
    btnNewProject : TToolButton;
    btnOpenProject: TToolButton;
    btnShowProjectFolder: TToolButton;
    btnSettings: TToolButton;
    btnTranslator : TToolButton;
    btnBuildWiki:  TToolButton;
    btnBuildWikiEn : TToolButton;
    btnShowWiki: TToolButton;
    btnToggleSideBar: TToolButton;
    btnToggleLog: TToolButton;
    btnCommit: TToolButton;
    btnPush: TToolButton;
    btnExit: TToolButton;

    SideBarPagerHandler: TPagerHandler;
    ContentPagerHandler: TPagerHandler;


    procedure FormInitialize();
    procedure FormFinalize();

    procedure PrepareToolBar();
    procedure ToggleSideBar();
    procedure ToggleLog();
    procedure BuildWiki(InEnglish: Boolean);
    procedure ShowWiki();
    procedure Commit();
    procedure Push();

    procedure Test();

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure DoShow; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
    function CloseQuery: Boolean; override;
  public

  end;




var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  Tripous.IconList
  ,Tripous.Logs
  ,o_app
  ,o_Entities
  ;

{ TMainForm }

procedure TMainForm.FormInitialize();
begin
  IconList.Load();
  PrepareToolBar();

  edtLog.Clear();

  pagerSideBar.Constraints.MinWidth:= 40;
  pnlContent.Constraints.MinWidth:= 40;
  pagerContent.Constraints.MinHeight:= 100;

  LogBox.Initialize(edtLog);

  pnlContent.Caption := '';
  AppOnProjectClosed(nil);

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;

  App.ClearPageControl(pagerSideBar);
  App.ClearPageControl(pagerContent);

  SideBarPagerHandler := TPagerHandler.Create(pagerSideBar);
  ContentPagerHandler := TPagerHandler.Create(pagerContent);

  App.SideBarPagerHandler := SideBarPagerHandler;
  App.ContentPagerHandler := ContentPagerHandler;

  App.Initialize(Self);

  // Test();
end;

procedure TMainForm.FormFinalize();
begin
  FreeAndNil(ContentPagerHandler);
  FreeAndNil(SideBarPagerHandler);
end;

procedure TMainForm.PrepareToolBar();
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  btnNewProject := IconList.AddButton(ToolBar, 'application_add', 'New Project', AnyClick);
  btnOpenProject := IconList.AddButton(ToolBar, 'application_go', 'Open Project', AnyClick);
  btnShowProjectFolder := IconList.AddButton(ToolBar, 'folder_go', 'Show Project Folder', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnSettings := IconList.AddButton(ToolBar, 'setting_tools', 'Settings', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnTranslator := IconList.AddButton(ToolBar, 'language', 'Translator', AnyClick);
  btnBuildWiki := IconList.AddButton(ToolBar, 'compile', 'Build Wiki', AnyClick);
  btnBuildWikiEn := IconList.AddButton(ToolBar, 'compile', 'Build Wiki in English', AnyClick);
  btnShowWiki := IconList.AddButton(ToolBar, 'bookshelf', 'Show Wiki', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnToggleSideBar := IconList.AddButton(ToolBar, 'layout_sidebar', 'Toggle SideBar', AnyClick);
  btnToggleLog := IconList.AddButton(ToolBar, 'error_log', 'Toggle Log', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnCommit := IconList.AddButton(ToolBar, 'book', 'Commit to git', AnyClick);
  btnPush := IconList.AddButton(ToolBar, 'book_go', 'Push to Remote git repository', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnExit := IconList.AddButton(ToolBar, 'door_out', 'Exit', AnyClick);

end;

procedure TMainForm.ToggleSideBar();
begin
  pagerSideBar.Visible := not pagerSideBar.Visible ;
  splitMain.Visible := pagerSideBar.Visible;
end;

procedure TMainForm.ToggleLog();
begin
  edtLog.Visible := not edtLog.Visible ;
  splitContent.Visible := edtLog.Visible;
end;

procedure TMainForm.BuildWiki(InEnglish: Boolean);
begin

end;

procedure TMainForm.ShowWiki();
begin

end;

procedure TMainForm.Commit();
begin

end;

procedure TMainForm.Push();
begin

end;

procedure TMainForm.Test();
var
  Project: TProject;
  Story: TStory;
  Chapter: TChapter;
  Scene: TScene;
  Component: TSWComponent;

  JsonText : string;
begin
  Project := TProject.Create();
  Project.Title := 'Project 1';

  Component := Project.ComponentList.Add();

  Component.Title := 'Comp 1';
  Component.TagList.Add('Planet');
  Component.TagList.Add('Location');

  Story := Project.StoryList.Add();
  Story.Title := 'Nice Story';

  Chapter := Story.ChapterList.Add();
  Chapter.Title := 'Space Battle';

  Scene := Chapter.SceneList.Add();
  Scene.Title := 'Very Dramatic';

  JsonText := Json.Serialize(Project);
  LogBox.AppendLine(JsonText);

  LogBox.AppendLine('===============================================================');
  LogBox.AppendLine('===============================================================');


  Project := TProject.Create();
  Json.Deserialize(Project, JsonText);

  JsonText := Json.Serialize(Project);
  LogBox.AppendLine(JsonText);

end;

procedure TMainForm.AnyClick(Sender: TObject);
begin
  if btnNewProject = Sender  then
     App.CreateNewProject()
  else if btnOpenProject = Sender  then
     App.OpenProject()
  else if (btnShowProjectFolder = Sender) and Assigned(App.CurrentProject) then
    App.DisplayFileExplorer(App.CurrentProject.ProjectFilePath)
  else if btnSettings = Sender  then
    App.ShowSettingsDialog()
  else if btnTranslator = Sender  then
    App.ShowTranslator()
  else if btnToggleSideBar = Sender  then
    ToggleSideBar()
  else if btnToggleLog = Sender  then
    ToggleLog()
  else if btnBuildWiki = Sender  then
    BuildWiki(False)
  else if btnBuildWikiEn = Sender  then
    BuildWiki(True)
  else if btnShowWiki = Sender  then
    ShowWiki()
  else if btnCommit = Sender  then
    Commit()
  else if btnPush = Sender  then
    Push()
  else if btnExit = Sender  then
    Close();
end;

procedure TMainForm.AppOnProjectOpened(Sender: TObject);
begin
  Self.Caption := Format('%s - [none]', [App.CurrentProject.Title]);
  StatusBar.Panels[0].Text := Self.Caption;
end;

procedure TMainForm.AppOnProjectClosed(Sender: TObject);
begin
  Self.Caption := Format('%s - [none]', [STitle]);
  StatusBar.Panels[0].Text := Self.Caption;
end;

procedure TMainForm.DoCreate;
begin
  inherited DoCreate;
  FormInitialize();
end;

procedure TMainForm.DoDestroy;
begin
  FormFinalize();
  inherited DoDestroy;
end;

procedure TMainForm.DoShow;
begin
  inherited DoShow;
end;

procedure TMainForm.DoClose(var CloseAction: TCloseAction);
begin
  LogBox.Finalize();
  inherited DoClose(CloseAction);
end;

function TMainForm.CloseQuery: Boolean;
begin
  Result := inherited CloseQuery;
  //Result := True;
end;

initialization
{$I Images.lrs}

end.

