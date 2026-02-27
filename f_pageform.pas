unit f_PageForm;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , ComCtrls
  , Graphics
  , Dialogs
  , LCLType
  , Tripous.Broadcaster
  ,o_Entities
  ,o_TextEditor
  ;

type

  { TPageForm }
  TPageForm = class(TForm)
  private
    fCloseableByUser: Boolean;
    fPageId: string;
    fInfo: TObject;
    fIsInitialized: Boolean;
  protected
    fBroadcasterToken: TBroadcastToken;
    fTitleText: string;

    function  GetParentTabPage: TTabSheet; virtual;
    procedure SetTitleText(AValue: string); virtual;

    procedure DoShow; override;

    procedure FormInitialize(); virtual;
    procedure FormInitializeAfter(); virtual;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function  CanCloseForm(): Boolean; virtual;

    procedure TitleChanged(); virtual;
    procedure AdjustTabTitle(); virtual;

    // ● editor handler
    procedure SaveEditorText(TextEditor: TTextEditor); virtual;
    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); virtual;

    // ● toolbar
    function AddButton(AToolBar: TToolBar; const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
    function AddSeparator(AToolBar: TToolBar): TToolButton;

    // ● properties
    property PageId : string read fPageId write fPageId;
    property CloseableByUser: Boolean read fCloseableByUser write fCloseableByUser;
    property Info: TObject read fInfo write fInfo;

    property TitleText: string read fTitleText write SetTitleText;
    property ParentTabPage: TTabSheet read GetParentTabPage;
    property IsInitialized: Boolean read fIsInitialized;
  end;

  TPageFormClass = class of TPageForm;

implementation

{$R *.lfm}

uses
  Tripous
  ,Tripous.IconList
  ;


{ TPageForm }

constructor TPageForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BorderStyle := bsNone;
  BorderIcons := [];
  Position := poDesigned;
  ShowInTaskBar := stNever;
  Align := alClient;
  Visible := False;

  fBroadcasterToken := Broadcaster.Register(OnBroadcasterEvent);
end;

destructor TPageForm.Destroy;
begin
  Broadcaster.Unregister(fBroadcasterToken);
  inherited Destroy;
end;


procedure TPageForm.FormInitialize();
begin
end;

procedure TPageForm.FormInitializeAfter();
begin

end;

procedure TPageForm.SetTitleText(AValue: string);
begin
  if fTitleText <> AValue then
  begin
    fTitleText := AValue;
    TitleChanged();
  end;
end;

function TPageForm.GetParentTabPage: TTabSheet;
begin
  if Self.Parent is TTabSheet then
     Result := Self.Parent as TTabSheet
  else
    Result := nil;
end;

procedure TPageForm.DoShow;
begin
  inherited DoShow;

  if not IsInitialized then
  begin
    FormInitialize();
    Sys.RunOnce(300 * 10, FormInitializeAfter);
    fIsInitialized := True;
  end;
end;



procedure TPageForm.TitleChanged();
begin
  AdjustTabTitle();
end;

procedure TPageForm.AdjustTabTitle();
begin
end;

procedure TPageForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
begin
end;

function TPageForm.CanCloseForm(): Boolean;
begin
  Result := True;
end;

procedure TPageForm.SaveEditorText(TextEditor: TTextEditor);
begin
end;

procedure TPageForm.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
begin
end;

function TPageForm.AddButton(AToolBar: TToolBar; const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
begin
  Result := IconList.AddButton(AToolBar, AIconName, AHint, AOnClick);
end;

function TPageForm.AddSeparator(AToolBar: TToolBar): TToolButton;
begin
  Result := IconList.AddSeparator(AToolBar);
end;


end.

