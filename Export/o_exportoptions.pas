unit o_ExportOptions;

{$mode delphi}

interface

type
  { Flags-style sets (C# [Flags] equivalent) }

  TExportLanguage = (elGreek, elEnglish);
  TExportLanguages = set of TExportLanguage;

  TExportSource = (esText, esSynopsis);
  TExportSources = set of TExportSource;

  TExportFormat = (efTXT, efODT);
  TExportFormats = set of TExportFormat;

  TExportTitleOption = (etoBullet, etoNumber, etoWord, etoTitle);
  TExportTitleOptions = set of TExportTitleOption;

  TExportOptions = class
  private
    FSingleComponentText: Boolean;
    FPreEditScenes: Boolean;
    FPreEditChapters: Boolean;

    FLanguage: TExportLanguages;
    FFormat: TExportFormats;
    FSource: TExportSources;
    FChapterTitle: TExportTitleOptions;
    FSceneTitle: TExportTitleOptions;
  public
    constructor Create;

    procedure Clear;

    { When true, then a file is created containing the text of all of the components }
    property SingleComponentText: Boolean read FSingleComponentText write FSingleComponentText;

    { When true, then a separate pre-edit file will be created for each scene }
    property PreEditScenes: Boolean read FPreEditScenes write FPreEditScenes;

    { When true, then a separate pre-edit file will be created for each chapter }
    property PreEditChapters: Boolean read FPreEditChapters write FPreEditChapters;

    { Defaults match the C# initializers }
    property Language: TExportLanguages read FLanguage write FLanguage;
    property Format: TExportFormats read FFormat write FFormat;
    property Source: TExportSources read FSource write FSource;
    property ChapterTitle: TExportTitleOptions read FChapterTitle write FChapterTitle;
    property SceneTitle: TExportTitleOptions read FSceneTitle write FSceneTitle;
  end;

implementation

constructor TExportOptions.Create;
begin
  inherited Create;

  { C# defaults:
      Language = Greek
      Format   = TXT
      Source   = Synopsis
      ChapterTitle/SceneTitle = Bullet|Word|Number|Title
  }
  FLanguage := [elGreek];
  FFormat := [efTXT];
  FSource := [esSynopsis];
  FChapterTitle := [etoBullet, etoWord, etoNumber, etoTitle];
  FSceneTitle := [etoBullet, etoWord, etoNumber, etoTitle];

  FSingleComponentText := False;
  FPreEditScenes := False;
  FPreEditChapters := False;
end;

procedure TExportOptions.Clear;
begin
  FLanguage := [];
  FFormat := [];
  FSource := [];
  FChapterTitle := [];
  FSceneTitle := [];

  FSingleComponentText := False;
  FPreEditScenes := False;
  FPreEditChapters := False;
end;

end.
