unit MainForm;

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
  ,LResources
  , ExtCtrls
  , StdCtrls
  ,Tripous
  ,Tripous.Broadcaster
  ,o_PageHandler

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

    fBroadcasterToken: TBroadcastToken;

    SideBarPagerHandler: TPagerHandler;
    ContentPagerHandler: TPagerHandler;


    procedure FormInitialize();
    procedure FormFinalize();

    procedure OnBroadcasterEvent(Args: TBroadcasterArgs);

    procedure PrepareToolBar();
    procedure ToggleSideBar();
    procedure ToggleLog();
    procedure BuildWiki(InEnglish: Boolean);
    procedure ShowWiki();
    procedure Commit();
    procedure Push();

    // ● event handler
    procedure AnyClick(Sender: TObject);
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure DoShow; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CloseQuery: Boolean; override;
  end;




var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
   Tripous.IconList
  ,Tripous.Logs
  ,o_Consts
  ,o_App
  ,o_Entities
  ,o_Cli
  ,o_GitCli
  ,o_WikiInfo
  ,o_Wiki
  ,f_GitCommitMessageDialog
  ;

{ TMainForm }

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fBroadcasterToken := Broadcaster.Register(OnBroadcasterEvent);
  IconList.SetResourceNames(IconResourceNames);
end;

destructor TMainForm.Destroy;
begin
  Broadcaster.Unregister(fBroadcasterToken);
  inherited Destroy;
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

  App.ClearPageControl(pagerSideBar);
  App.ClearPageControl(pagerContent);

  SideBarPagerHandler := TPagerHandler.Create(pagerSideBar);
  ContentPagerHandler := TPagerHandler.Create(pagerContent);

  App.SideBarPagerHandler := SideBarPagerHandler;
  App.ContentPagerHandler := ContentPagerHandler;

  App.Initialize(Self);

  pagerSideBar.Width:= 560;

end;

procedure TMainForm.FormFinalize();
begin
  FreeAndNil(ContentPagerHandler);
  FreeAndNil(SideBarPagerHandler);
end;

procedure TMainForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekProjectOpened :
    begin
      Self.Caption := Format('%s - [none]', [App.CurrentProject.Title]);
      StatusBar.Panels[0].Text := Self.Caption;
    end;
    aekProjectClosed :
    begin
      Self.Caption := Format('%s - [none]', [STitle]);
      StatusBar.Panels[0].Text := Self.Caption;
    end;
  end;
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
var
  WikiBuildInfo: TWikiBuildInfo;
  BuildResult: TWikiBuildResult;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    WikiBuildInfo := TWikiBuildInfo.Create(InEnglish);
    try
      BuildResult := Wiki.Build(WikiBuildInfo);
      if Assigned(BuildResult) then
      begin
        LogBox.AppendLine('Build result follows:');
        LogBox.AppendLine(BuildResult.Log.Text);
      end;
    finally
      WikiBuildInfo.Free();
    end;
  finally
    Screen.Cursor := crDefault;
    Application.ProcessMessages;
  end;
end;

procedure TMainForm.ShowWiki();
begin
  // TODO: TMainForm.ShowWiki
end;

procedure TMainForm.Commit;
var
  ProjectFolderPath: string;
  DT: string;
  CommitMessage: string;
  GitIgnoreText: string;
begin
  if (App.CurrentProject = nil) then
    Exit;

  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    ProjectFolderPath := App.CurrentProject.FolderPath;

    if not GitCli.IsGitRepo(ProjectFolderPath) then
    begin
      LogBox.AppendLine('Initializing git repo.');
      Application.ProcessMessages;

      GitCli.EnsureIsRepo(ProjectFolderPath);

      GitIgnoreText :=
        '**/bin' + LineEnding +
        '**/obj' + LineEnding +
        '**/.vs' + LineEnding +
        '**/Wiki' + LineEnding +
        '**/Export';

      with TStringList.Create do
      try
        Text := GitIgnoreText;
        SaveToFile(IncludeTrailingPathDelimiter(ProjectFolderPath) + '.gitignore');
      finally
        Free;
      end;

      LogBox.AppendLine('Initialized git repo, added files and done the initial commit.');
    end
    else
    begin
      if not GitCli.HasUncommittedChanges(ProjectFolderPath) then
      begin
        LogBox.AppendLine('There are no uncommitted changes.');
        App.InfoBox('There are no uncommitted changes.');
        Exit;
      end;

      DT := FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', Now);
      CommitMessage := 'Auto-commit ' + DT;

      if not TGitCommitMessageDialog.ShowDialog(CommitMessage) then
        Exit;

      LogBox.AppendLine(Format('Commiting to git with message: "%s"... Please wait...', [CommitMessage]));

      if not GitCli.CommitIfNeeded(ProjectFolderPath, CommitMessage) then
        LogBox.AppendLine('Nothing to commit.')
      else
        LogBox.AppendLine('COMMITTED.');
    end;
  finally
    Screen.Cursor := crDefault;
    Application.ProcessMessages;
  end;
end;

procedure TMainForm.Push;
var
  Message: string;
  ProjectFolderPath: string;
  GitResult: TCliResult;
begin
  if (App.CurrentProject = nil) then
    Exit;

  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    ProjectFolderPath := App.CurrentProject.FolderPath;

    if not GitCli.IsGitRepo(ProjectFolderPath) then
    begin
      Message := Format('There is no git repo in folder: %s.', [ProjectFolderPath]);
      LogBox.AppendLine(Message);
      App.WarningBox(Message);
      Exit;
    end;

    LogBox.AppendLine('Checking for uncommitted changes...');
    if GitCli.HasUncommittedChanges(ProjectFolderPath) then
    begin
      Message := 'There are uncommitted changes.' + LineEnding + 'Please commit them first.';
      LogBox.AppendLine(Message);
      App.WarningBox(Message);
      Exit;
    end;

    LogBox.AppendLine('Pushing to remote git repository... Please wait...');
    LogBox.AppendLine('Starting push operation...');

    GitResult := GitCli.Push(ProjectFolderPath);

    if GitResult.Succeeded then
      LogBox.AppendLine('Pushing to remote git repository SUCCEEDED.')
    else
      LogBox.AppendLine('Pushing to remote git repository FAILED.');

    LogBox.AppendLine('Git output follows:');
    LogBox.AppendLine(GitResult.ToText);
  finally
    Screen.Cursor := crDefault;
    Application.ProcessMessages;
  end;
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


end.

