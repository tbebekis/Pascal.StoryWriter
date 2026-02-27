unit o_MarkDownPreview;

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
  , IpHtml
  , MarkdownProcessor
  , MarkdownUtils
  , IpFileBroker
  ;

type

  { TMarkdownPreview }

  TMarkdownPreview = class(TIpHtmlPanel)
  private
    HtmlDataProvider: TIpHtmlDataProvider;
    fOnRefreshMarkdownText: TNotifyEvent;
    procedure HtmlOnGetImage(Sender: TIpHtmlNode; const URL: string; var Picture: TPicture);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure SetMarkdownText(const MarkdownText: string);

    property OnRefreshMarkdownText: TNotifyEvent read fOnRefreshMarkdownText write fOnRefreshMarkdownText;
  end;

implementation

uses
  LCLType
  ,o_App
  ;

type

  { THtmlDataProvider }

  THtmlDataProvider = class(TIpHtmlDataProvider)
  public
    function DoGetStream(const URL: string): TStream; override;
  end;

{ THtmlDataProvider }

function THtmlDataProvider.DoGetStream(const URL: string): TStream;
begin
  Result := nil;
end;




{ TMarkdownPreview }

constructor TMarkdownPreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  HtmlDataProvider := THtmlDataProvider.Create(Self);
  Self.DataProvider := HtmlDataProvider;
  HtmlDataProvider.OnGetImage := HtmlOnGetImage;

  Align := alClient;
end;

destructor TMarkdownPreview.Destroy();
begin
  inherited Destroy();
end;

procedure TMarkdownPreview.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  if Key = VK_TAB then
  begin
    if Assigned(fOnRefreshMarkdownText) then
      fOnRefreshMarkdownText(Self);

    Key := 0;
  end;
end;

procedure TMarkdownPreview.HtmlOnGetImage(Sender: TIpHtmlNode; const URL: string; var Picture: TPicture);
var
  FileName: string;
  FullPath: string;
begin
  Picture := nil;

  if not Assigned(App.CurrentProject) then
    Exit;

  if URL = '' then
    Exit;

  FileName := ExtractFileName(URL);

  FullPath := IncludeTrailingPathDelimiter(App.CurrentProject.ImagesFolderPath) + FileName;

  if FileExists(FullPath) then
  begin
    Picture := TPicture.Create;
    Picture.LoadFromFile(FullPath);
  end;

end;

procedure TMarkdownPreview.SetMarkdownText(const MarkdownText: string);
var
  Md: TMarkdownProcessor;
  HtmlFrag, HtmlFull: string;
begin
  Md := TMarkdownProcessor.CreateDialect(mdCommonMark);
  try
    Md.UnSafe := False; // safer default

    // Markdown -> HTML fragment
    HtmlFrag := Md.process(MarkdownText);

    // Wrap fragment to full HTML (IpHtmlPanel likes full doc)
    HtmlFull :=
      '<html><head><meta charset="utf-8">' +
      '<style>' +
      'body{font-family:sans-serif;font-size:14px;padding:12px;}' +
      'pre{white-space:pre-wrap;}' +
      'code,pre{font-family:monospace;}' +
      '</style>' +
      '</head><body>' +
      HtmlFrag +
      '</body></html>';

    (*
    HtmlFull :=
      '<html><head><meta charset="utf-8">' +
      '<style>' + DefaultCssText + '</style>' +
      '</head><body>' +
      HtmlFrag +
      '</body></html>';
    *)

    // Show it
    Self.SetHtmlFromStr(HtmlFull);
  finally
    Md.Free;
  end;

end;

end.

