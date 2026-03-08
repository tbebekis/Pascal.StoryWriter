unit o_GitCli;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes, o_Cli;

type
  { full static class }
  GitCli = class
  public
    class function Git(const GitArguments, RepoDir: string;
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    class function GitBatch(const GitArgsList: array of string; const RepoDir: string;
      TimeoutPerCommandMs: Integer = 120 * 1000;
      StopOnError: Boolean = True;
      Env: TStrings = nil): TCliResultArray; static;

    class function IsGitRepo(const ProjectFolderPath: string): Boolean; static;
    class function EnsureIsRepo(const ProjectFolderPath: string): Boolean; static;
    class function HasUncommittedChanges(const ProjectFolderPath: string): Boolean; static;

    class function CommitIfNeeded(const ProjectFolderPath: string;
      const MessageText: string = ''): Boolean; static;

    class function Push(const RepoDir: string;
      const RemoteName: string = 'origin';
      const Branch: string = 'main';
      TimeoutMs: Integer = 120 * 1000): TCliResult; static;

    class function HasGlobalCredentialHelper: Boolean; static;
    class function GetGlobalCredentialHelper: string; static;
    class function EnsureGithubCredentials(const UserName, Token: string): Boolean; static;

    class function TryGetGithubStoredCredentials(const UserName: string; out StoredUser, StoredToken: string): Boolean; static;
    class function HasGithubStoredCredentials(const UserName: string = ''): Boolean; static;

    class function CreateGitEnv: TStringList;
  end;

implementation

function TrimLineEndings(const S: string): string;
begin
  Result := StringReplace(S, #13, '', [rfReplaceAll]);
end;

function HasRemote(const RemoteListText, RemoteName: string): Boolean;
var
  SL: TStringList;
  i: Integer;
  Line: string;
begin
  Result := False;
  SL := TStringList.Create;
  try
    SL.Text := TrimLineEndings(RemoteListText);
    for i := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[i]);
      if SameText(Line, RemoteName) then
        Exit(True);
    end;
  finally
    SL.Free;
  end;
end;

function GetCredentialValue(const Text, Key: string): string;
var
  SL: TStringList;
  i: Integer;
  Prefix, Line: string;
begin
  Result := '';
  Prefix := Key + '=';

  SL := TStringList.Create;
  try
    SL.Text := StringReplace(Text, #13, '', [rfReplaceAll]);

    for i := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[i]);
      if Pos(Prefix, Line) = 1 then
        Exit(Copy(Line, Length(Prefix) + 1, MaxInt));
    end;
  finally
    SL.Free;
  end;
end;

class function GitCli.Git(const GitArguments, RepoDir: string;
  TimeoutMs: Integer; Env: TStrings): TCliResult;
begin
  Result := CLI.RunExe('git', GitArguments, RepoDir, TimeoutMs, Env);
end;

class function GitCli.GitBatch(const GitArgsList: array of string; const RepoDir: string;
  TimeoutPerCommandMs: Integer; StopOnError: Boolean; Env: TStrings): TCliResultArray;
var
  i, n: Integer;
  R: TCliResult;
  Res: TCliResultArray;
begin
  Res := nil;
  n := 0;

  for i := Low(GitArgsList) to High(GitArgsList) do
  begin
    if Trim(GitArgsList[i]) = '' then
      Continue;

    R := Git(GitArgsList[i], RepoDir, TimeoutPerCommandMs, Env);

    SetLength(Res, n + 1);
    Res[n] := R;
    Inc(n);

    if StopOnError and (not R.Succeeded) then
      Break;
  end;

  Result := Res;
end;

class function GitCli.IsGitRepo(const ProjectFolderPath: string): Boolean;
begin
  Result := DirectoryExists(IncludeTrailingPathDelimiter(ProjectFolderPath) + '.git');
end;

class function GitCli.EnsureIsRepo(const ProjectFolderPath: string): Boolean;
var
  GitFolder: string;
  R: TCliResult;
begin
  if (Trim(ProjectFolderPath) = '') or (not DirectoryExists(ProjectFolderPath)) then
    raise Exception.CreateFmt('Folder not exists: %s', [ProjectFolderPath]);

  GitFolder := IncludeTrailingPathDelimiter(ProjectFolderPath) + '.git';
  if DirectoryExists(GitFolder) then
    Exit(True);

  R := Git('init', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git init'' in folder: %s', [ProjectFolderPath]);

  // force main (for older git)
  R := Git('symbolic-ref HEAD refs/heads/main', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Warning cannot set HEAD to ''main'': %s'#10'%s', [ProjectFolderPath, R.StdErr]);

  R := Git('add .', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git add'' in folder: %s'#10'%s', [ProjectFolderPath, R.StdErr]);

  R := Git('commit -m "Initial commit"', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git commit'' in folder: %s'#10'%s', [ProjectFolderPath, R.StdErr]);

  Result := True;
end;

class function GitCli.HasUncommittedChanges(const ProjectFolderPath: string): Boolean;
var
  R: TCliResult;
  S : string;
begin
  if (Trim(ProjectFolderPath) = '') or (not DirectoryExists(ProjectFolderPath)) then
    raise Exception.CreateFmt('Folder not exists: %s', [ProjectFolderPath]);

  if not IsGitRepo(ProjectFolderPath) then
    raise Exception.CreateFmt('Folder is not a git repo: %s', [ProjectFolderPath]);

  R := Git('status --porcelain', ProjectFolderPath);
  if not R.Succeeded then
  begin
    S := R.ToText();
    raise Exception.CreateFmt('Failed to ''git status'':'#10'%s', [S]);
  end;

  Result := Trim(R.StdOut) <> '';
end;

class function GitCli.CommitIfNeeded(const ProjectFolderPath: string; const MessageText: string): Boolean;
var
  Msg: string;
  DT: string;
  R: TCliResult;
begin
  if not HasUncommittedChanges(ProjectFolderPath) then
    Exit(False);

  R := Git('add -A', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git add'':'#10'%s', [R.StdErr]);

  Msg := Trim(MessageText);
  if Msg = '' then
  begin
    DT := FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', Now);
    Msg := 'Auto-commit ' + DT;
  end;

  // basic quoting. If you may have quotes in Msg, we can escape them.
  R := Git('commit -m "' + Msg + '"', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git commit'':'#10'%s', [R.StdErr]);

  Result := True;
end;


class function GitCli.Push(const RepoDir, RemoteName, Branch: string; TimeoutMs: Integer): TCliResult;
var
  Env: TStringList;
begin
  if (Trim(RepoDir) = '') or (not DirectoryExists(RepoDir)) then
    raise Exception.CreateFmt('Folder not exists: %s', [RepoDir]);

  if not IsGitRepo(RepoDir) then
    raise Exception.CreateFmt('Folder is not a git repo: %s', [RepoDir]);

  Env := CreateGitEnv;
  try
    Env.Values['GIT_TERMINAL_PROMPT'] := '0';

    Result := Git(Format('push %s %s', [RemoteName, Branch]), RepoDir, TimeoutMs, Env);

    if not Result.Succeeded then
      raise Exception.CreateFmt('Failed to push: %s', [Result.ToText]);
  finally
    Env.Free;
  end;
end;

class function GitCli.HasGlobalCredentialHelper: Boolean;
begin
  Result := Trim(GetGlobalCredentialHelper) <> '';
end;

class function GitCli.GetGlobalCredentialHelper: string;
var
  R: TCliResult;
begin
  R := CLI.RunExe('git', 'config --global credential.helper');

  // Αν δεν υπάρχει setting, συνήθως το git γυρίζει non-zero και άδειο output.
  if R.Succeeded then
    Result := Trim(R.StdOut)
  else
    Result := '';
end;

class function GitCli.EnsureGithubCredentials(const UserName, Token: string): Boolean;
var
  HelperName: string;
  InputText: string;
  R: TCliResult;
begin
  if Trim(UserName) = '' then
    raise Exception.Create('GitHub user name is empty.');

  if Trim(Token) = '' then
    raise Exception.Create('GitHub token is empty.');

  HelperName := GetGlobalCredentialHelper;

  if HelperName = '' then
  begin
    R := CLI.RunExe('git', 'config --global credential.helper store');
    if not R.Succeeded then
      raise Exception.CreateFmt(
        'Failed to configure git credential.helper.' + LineEnding + '%s',
        [R.ToText]
      );
  end;

  InputText :=
    'protocol=https' + LineEnding +
    'host=github.com' + LineEnding +
    'username=' + UserName + LineEnding +
    'password=' + Token + LineEnding +
    LineEnding;

  R := CLI.RunExeWithInput('git', 'credential approve', InputText);
  if not R.Succeeded then
    raise Exception.CreateFmt(
      'Failed to store GitHub credentials.' + LineEnding + '%s',
      [R.ToText]
    );

  Result := True;
end;

class function GitCli.CreateGitEnv: TStringList;
var
  UserDir: string;
begin
  Result := TStringList.Create;
  UserDir := ExcludeTrailingPathDelimiter(GetUserDir);

  {$IFDEF UNIX}
  Result.Values['HOME'] := UserDir;
  Result.Values['GIT_CONFIG_GLOBAL'] := UserDir + PathDelim + '.gitconfig';
  {$ENDIF}

  {$IFDEF Windows}
  Result.Values['USERPROFILE'] := UserDir;
  Result.Values['GIT_CONFIG_GLOBAL'] := UserDir + PathDelim + '.gitconfig';
  {$ENDIF}
end;

class function GitCli.TryGetGithubStoredCredentials(
  const UserName: string;
  out StoredUser, StoredToken: string): Boolean;
var
  InputText: string;
  R: TCliResult;
  HelperName: string;
begin
  Result := False;
  StoredUser := '';
  StoredToken := '';

  HelperName := GetGlobalCredentialHelper;
  if Trim(HelperName) = '' then
    Exit(False);

  InputText :=
    'protocol=https' + LineEnding +
    'host=github.com' + LineEnding;

  if Trim(UserName) <> '' then
    InputText := InputText + 'username=' + UserName + LineEnding;

  InputText := InputText + LineEnding;

  R := CLI.RunExeWithInput('git', 'credential fill', InputText);

  if R.TimedOut then
    raise Exception.CreateFmt(
      'Timed out while checking stored GitHub credentials.' + LineEnding + '%s',
      [R.ToText]
    );

  if not R.Succeeded then
  begin
    // Εδώ δεν κάνουμε raise. Το "δεν βρέθηκαν credentials" είναι φυσιολογική κατάσταση.
    Exit(False);
  end;

  StoredUser := GetCredentialValue(R.StdOut, 'username');
  StoredToken := GetCredentialValue(R.StdOut, 'password');

  Result := Trim(StoredToken) <> '';
end;

class function GitCli.HasGithubStoredCredentials(const UserName: string): Boolean;
var
  U, T: string;
begin
  Result := TryGetGithubStoredCredentials(UserName, U, T);
end;

end.
