unit fr_MarkdownPreview;

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
  , IpHtml
  , SynEdit
  , MarkdownProcessor
  , MarkdownUtils
  , IpFileBroker
  ;

type

  { TMarkdownPreview }

  TMarkdownPreview = class(TFrame)
    HtmlPanel: TIpHtmlPanel;
    HtmlDataProvider: TIpHtmlDataProvider;
  private
    fOnRefreshMarkdownText: TNotifyEvent;


    procedure HtmlOnGetImage(Sender: TIpHtmlNode; const URL: string; var Picture: TPicture);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;

    procedure SetMarkdownText(const MarkdownText: string);

    property OnRefreshMarkdownText: TNotifyEvent read fOnRefreshMarkdownText write fOnRefreshMarkdownText;
  end;

implementation

{$R *.lfm}

uses
  LCLType
  ,o_App
  ;

{ TMarkdownPreview }

constructor TMarkdownPreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  HtmlPanel.DataProvider := HtmlDataProvider;
  HtmlDataProvider.OnGetImage := HtmlOnGetImage;
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
    HtmlPanel.SetHtmlFromStr(HtmlFull);
  finally
    Md.Free;
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



end.

