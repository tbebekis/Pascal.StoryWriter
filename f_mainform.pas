unit f_MainForm;

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
  , ExtCtrls
  , StdCtrls
  , Dialogs
  , Menus
  , DBGrids
  , ComCtrls
  , TypInfo
  , Variants

  ,LazFileUtils
  ,LResources
  ,Tripous
  ,Tripous.Broadcaster
  ,Tripous.Cli
  ,Tripous.GitCli
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

    IsInitialized: Boolean;
    fBroadcasterToken: TBroadcastToken;

    SideBarPagerHandler: TPagerHandler;
    ContentPagerHandler: TPagerHandler;

    Cli: TCli;
    GitCli: TGitCli;

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

    procedure InitializeHighlighters();

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppException(Sender: TObject; E: Exception);
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
  ,o_WikiInfo
  ,o_Wiki
   ,o_Highlighters
   ,Zipper
  ,f_GitCommitMessageDialog
   ,f_GithubCredentialsDialog
  ;

{ TMainForm }

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  LogBox.Initialize(edtLog);
  Application.OnException := AppException;
  fBroadcasterToken := Broadcaster.Register(OnBroadcasterEvent);
  IconList.SetResourceNames(IconResourceNames);
  InitializeHighlighters();

  Cli := TCli.Create();
  GitCli := TGitCli.Create(Cli);
end;

destructor TMainForm.Destroy;
begin
  GitCli.Free();
  Cli.Free();
  Broadcaster.Unregister(fBroadcasterToken);
  inherited Destroy;
end;

procedure TMainForm.DoCreate;
begin
  inherited DoCreate;
end;

procedure TMainForm.DoDestroy;
begin
  FormFinalize();
  inherited DoDestroy;
end;

procedure TMainForm.DoShow;
begin
  inherited DoShow;
  if not IsInitialized then
  begin
    FormInitialize();
    IsInitialized := True;
  end;
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
      Self.Caption := Format('%s - [%s]', [STitle, App.CurrentProject.Title]);
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
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
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
  finally
    ToolBar.Parent := P;
  end;

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
  GitIgnoreFilePath: string;
begin
  if App.CurrentProject = nil then
    Exit;

  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    ProjectFolderPath := App.CurrentProject.FolderPath;
    GitCli.RepoDir := ProjectFolderPath;

    if not GitCli.IsGitRepo then
    begin
      LogBox.AppendLine('Initializing git repository...');
      Application.ProcessMessages;

      GitCli.InitRepo;

      GitIgnoreText :=
        '**/bin' + LineEnding +
        '**/obj' + LineEnding +
        '**/.vs' + LineEnding +
        '**/Wiki' + LineEnding +
        '**/Export';

      GitIgnoreFilePath := IncludeTrailingPathDelimiter(ProjectFolderPath) + '.gitignore';

      with TStringList.Create do
      try
        Text := GitIgnoreText;
        SaveToFile(GitIgnoreFilePath);
      finally
        Free;
      end;

      LogBox.AppendLine('Git repository initialized.');
    end;

    if not GitCli.HasUncommittedChanges then
    begin
      LogBox.AppendLine('There are no uncommitted changes.');
      App.InfoBox('There are no uncommitted changes.');
      Exit;
    end;

    DT := FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', Now);
    CommitMessage := 'Auto-commit ' + DT;

    if not TGitCommitMessageDialog.ShowDialog(CommitMessage) then
      Exit;

    LogBox.AppendLine(Format('Committing to git with message: "%s"... Please wait...', [CommitMessage]));

    if not GitCli.CommitIfNeeded(CommitMessage) then
      LogBox.AppendLine('Nothing to commit.')
    else
      LogBox.AppendLine('COMMITTED.');
  finally
    Screen.Cursor := crDefault;
    Application.ProcessMessages;
  end;
end;

procedure TMainForm.Push;
var
  Msg: string;
  ProjectFolderPath: string;
  GitResult: TCliResult;
  UserName: string;
  Token: string;
begin
  if App.CurrentProject = nil then
    Exit;

  Application.ProcessMessages;
  try
    ProjectFolderPath := App.CurrentProject.FolderPath;
    GitCli.RepoDir := ProjectFolderPath;

    if not GitCli.IsGitRepo then
    begin
      Msg := Format('There is no git repo in folder: %s.', [ProjectFolderPath]);
      LogBox.AppendLine(Msg);
      App.WarningBox(Msg);
      Exit;
    end;

    LogBox.AppendLine('Checking for uncommitted changes...');
    if GitCli.HasUncommittedChanges then
    begin
      Msg := 'There are uncommitted changes.' + LineEnding + 'Please commit them first.';
      LogBox.AppendLine(Msg);
      App.WarningBox(Msg);
      Exit;
    end;

    if not GitCli.HasGlobalCredentialHelper then
    begin
      UserName := '';
      Token := '';

      if not TGithubCredentialsDialog.ShowDialog(UserName, Token) then
        Exit;

      if not GitCli.EnsureGitHubCredentials(UserName, Token) then
      begin
        LogBox.AppendLine('Failed to store GitHub credentials.');
        Exit;
      end;
    end;

    LogBox.AppendLine('Pushing to remote git repository... Please wait...');

    GitResult := GitCli.Push;

    if GitResult.Success then
      LogBox.AppendLine('Pushing to remote git repository SUCCEEDED.')
    else
      LogBox.AppendLine('Pushing to remote git repository FAILED.');

    LogBox.AppendLine('Git output follows:');
    LogBox.AppendLine(GitResult.ToText);
  finally
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

procedure TMainForm.InitializeHighlighters();
var
  FolderPath: string;
  ZipFilePath: string;
  ResName : string;
  RS : TResourceStream;
  UnZ: TUnZipper;
begin

  FolderPath := Sys.CombinePath(App.ExeFolderPath, 'Highlighters');
  if not DirectoryExists(FolderPath) then
  begin
    ResName := 'HIGHLIGHTERS';
    ZipFilePath := Sys.CombinePath(App.ExeFolderPath, 'Highlighters.zip');

    RS := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
    try
      RS.SaveToFile(ZipFilePath);
    finally
      RS.Free;
    end;

    UnZ := TUnZipper.Create;
    try
      UnZ.FileName := ZipFilePath;
      UnZ.OutputPath := IncludeTrailingPathDelimiter(App.ExeFolderPath);
      UnZ.Examine;
      UnZ.UnZipAllFiles;
    finally
      UnZ.Free;
    end;
  end;

  if DirectoryExists(FolderPath) then
  begin
    THighlighters.Initialize(FolderPath);
    THighlighters.RegisterDefaults;
  end;
end;

procedure TMainForm.AppException(Sender: TObject; E: Exception);
//var
//  ErrorMessage: string;
begin
  //ErrorMessage := 'Unhandled exception:' + LineEnding + E.ClassName + ': ' + E.Message;
  LogBox.AppendLine(E);
end;


end.

