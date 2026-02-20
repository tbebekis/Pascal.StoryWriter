unit o_AppSettings;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

type
  { TAppSettings }
  TAppSettings = class
  private
    FLoadLastProjectOnStartup: Boolean;
    FLastProjectFolderPath: string;
    FAutoSave: Boolean;
    FAutoSaveSecondsInterval: Integer;
    FFontFamily: string;
    FFontSize: Integer;
    FZoomFactor: Currency;
    FMarkdownWebViewVisible: Boolean;
    FEnglishVisible: Boolean;

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
    property LoadLastProjectOnStartup: Boolean read FLoadLastProjectOnStartup write FLoadLastProjectOnStartup;
    property LastProjectFolderPath: string read FLastProjectFolderPath write FLastProjectFolderPath;
    property AutoSave: Boolean read FAutoSave write FAutoSave;
    property AutoSaveSecondsInterval: Integer read FAutoSaveSecondsInterval write FAutoSaveSecondsInterval;
    property FontFamily: string read FFontFamily write FFontFamily;
    property FontSize: Integer read FFontSize write FFontSize;
    property ZoomFactor: Currency read FZoomFactor write FZoomFactor;
    property MarkdownWebViewVisible: Boolean read FMarkdownWebViewVisible write FMarkdownWebViewVisible;
    property EnglishVisible: Boolean read FEnglishVisible write FEnglishVisible;
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
  FAutoSaveSecondsInterval := 30;
  FFontFamily := 'DejaVu Sans Mono';
  FFontSize := 13;
  FZoomFactor := 1.0;
  FMarkdownWebViewVisible := False;
  FEnglishVisible := False;
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

