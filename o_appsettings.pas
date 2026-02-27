unit o_AppSettings;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

type
  { TAppSettings }
  TAppSettings = class
  private
    fGutterVisible: Boolean;
    FLoadLastProjectOnStartup: Boolean;
    FLastProjectFolderPath: string;
    FAutoSave: Boolean;
    FAutoSaveSecondsInterval: Integer;
    fFontName: string;
    FFontSize: Integer;

    FEnglishVisible: Boolean;
    fMinimapTooltipVisible: Boolean;
    fMinimapVisible: Boolean;
    fRulerVisible: Boolean;
    fShowCurLine: Boolean;
    fUseHighlighters: Boolean;

    function GetFilePath: string;
  protected
    procedure BeforeLoad; virtual;
    procedure AfterLoad; virtual;
  public
    constructor Create;

    procedure Load;
    procedure Save;

    property FilePath: string read GetFilePath;
  published
    property AutoSave: Boolean read FAutoSave write FAutoSave;
    property AutoSaveSecondsInterval: Integer read FAutoSaveSecondsInterval write FAutoSaveSecondsInterval;

    property LoadLastProjectOnStartup: Boolean read FLoadLastProjectOnStartup write FLoadLastProjectOnStartup;
    property LastProjectFolderPath: string read FLastProjectFolderPath write FLastProjectFolderPath;
    property EnglishVisible: Boolean read FEnglishVisible write FEnglishVisible;

    property UseHighlighters: Boolean read fUseHighlighters write fUseHighlighters;
    property GutterVisible: Boolean read fGutterVisible write fGutterVisible;
    property RulerVisible: Boolean read fRulerVisible write fRulerVisible;
    property ShowCurLine: Boolean read fShowCurLine write fShowCurLine;
    property MinimapVisible: Boolean read fMinimapVisible write fMinimapVisible;
    property MinimapTooltipVisible: Boolean read fMinimapTooltipVisible write fMinimapTooltipVisible;

    property FontName: string read fFontName write fFontName;
    property FontSize: Integer read FFontSize write FFontSize;
  end;

implementation

uses
  Tripous
  ;

{ TAppSettings }

function TAppSettings.GetFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'AppSettings.json';
end;

procedure TAppSettings.BeforeLoad;
begin
  // for inheritors
end;

procedure TAppSettings.AfterLoad;
begin
  // for inheritors
end;

constructor TAppSettings.Create;
begin
  inherited Create;

  FLoadLastProjectOnStartup := True;
  FLastProjectFolderPath := '___';

  FAutoSave := True;
  FAutoSaveSecondsInterval := 15;
  fFontName := 'DejaVu Sans Mono';
  FFontSize := 10;

  FEnglishVisible := False;

  UseHighlighters := True;
  ShowCurLine := True;
end;

procedure TAppSettings.Load;
begin
  BeforeLoad;
  if FileExists(FilePath) then
    Json.LoadFromFile(FilePath, Self);
  AfterLoad;
end;

procedure TAppSettings.Save;
begin
  Json.SaveToFile(FilePath, Self);
end;

end.

