unit o_SearchAndReplace;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , StdCtrls
  , ComCtrls
  , ExtCtrls
  , Graphics
  , LCLType
  , SynEdit
  , SynEditTypes

  , SynEditSearch

  , LCLProc
  ;

type
  { TSearchAndReplace }
  TSearchAndReplace = class(TComponent)
  private
    fEditor: TSynEdit;
    fFoundCount: Integer;
  public
    // ● options
    TextToFind: string;
    ReplaceWith: string;

    MatchCase: Boolean;
    WholeWord: Boolean;
    SelectionOnly: Boolean;

    ReplaceFlag: Boolean;
    ReplaceAllFlag: Boolean;
    PromptOnReplace: Boolean;

    function NormalizeSearch(var Options: TSynSearchOptions): string;
  public
    constructor Create(AEditor: TSynEdit); overload;

    procedure ShowFindDialog();

    procedure Highlight();
    procedure ClearHighlights();

    procedure FindNext();
    procedure FindPrevious();

    procedure Replace(All: Boolean = True; Prompt: Boolean = True);

    function GetSynEditHighlightOptions: TSynSearchOptions;
    function GetSynEditSearchOptions(Backwards: Boolean): TSynSearchOptions;

    property Editor: TSynEdit read fEditor;
    property FoundCount: Integer read fFoundCount;
  end;

implementation

uses
   o_App
  , f_FindAndReplaceDialog
   , SynEditMiscClasses
   , SynEditHighlighter
   , SynHighlighterAny
  ;

function EscapeRegExprLiteral(const S: string): string;
const
  Meta: set of Char = ['\', '.', '^', '$', '|', '?', '*', '+', '(', ')', '[', ']', '{', '}'];
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    if S[i] in Meta then
      Result := Result + '\' + S[i]
    else
      Result := Result + S[i];
end;

// Byte-wise "word byte" class for UTF-8 Greek text:
// - ASCII word bytes: 0-9 A-Z a-z _
// - UTF-8 continuation bytes: 0x80..0xBF
// - Greek lead bytes in UTF-8 are commonly 0xCE or 0xCF
function BuildWholeWordUtf8GreekPattern(const Term: string): string;
const
  WordByteClass = '[0-9A-Za-z_\x80-\xBF\xCE\xCF]';
begin
  Result :=
    '(^|[^' + Copy(WordByteClass, 2, Length(WordByteClass)-2) + '])' + // group 1: left boundary or start
    '(' + EscapeRegExprLiteral(Term) + ')' +                           // group 2: the actual term
    '(?=$|[^' + Copy(WordByteClass, 2, Length(WordByteClass)-2) + '])';// right boundary (lookahead)
end;

// After a RegExpr whole-word match, selection may include the left boundary char.
// Trim selection so only the term is selected (better UX for FindNext/Prev).
procedure TrimLeftBoundarySelection(Editor: TSynEdit; const Term: string);
var
  S: string;
  BB, BE: TPoint;
begin
  if (Editor = nil) or (Term = '') then Exit;
  if not Editor.SelAvail then Exit;

  S := Editor.SelText;
  if (Length(S) = Length(Term) + 1) and (Copy(S, 2, Length(Term)) = Term) then
  begin
    BB := Editor.BlockBegin;
    BE := Editor.BlockEnd;
    Inc(BB.X); // skip the boundary char
    Editor.BlockBegin := BB;
    Editor.BlockEnd := BE;
  end;
end;






{ TSearchAndReplace }

constructor TSearchAndReplace.Create(AEditor: TSynEdit);
begin
  inherited Create(AEditor);
  fEditor := AEditor;

end;

procedure TSearchAndReplace.ShowFindDialog();
begin
  if TFindAndReplaceDialog.Execute(Self) then
  begin
    if ReplaceFlag or ReplaceAllFlag then
    begin
      Replace(ReplaceAllFlag, PromptOnReplace);
    end else begin
      Highlight();
      //FindNext();
    end;
  end;
end;

function TSearchAndReplace.GetSynEditHighlightOptions: TSynSearchOptions;
begin
  Result := [ssoEntireScope];

  if (MatchCase) then
     Include(Result, ssoMatchCase);

  if (WholeWord) then
     Include(Result, ssoWholeWord);
end;

function TSearchAndReplace.NormalizeSearch(var Options: TSynSearchOptions): string;
begin
  Result := TextToFind;
  if WholeWord then
  begin
    Exclude(Options, ssoWholeWord);
    Include(Options, ssoRegExpr);
    Result := BuildWholeWordUtf8GreekPattern(TextToFind);
  end;
end;

procedure TSearchAndReplace.Highlight();
var
  SynEditOptions: TSynSearchOptions;
  sText: string;
begin
  ClearHighlights();

  SynEditOptions := GetSynEditHighlightOptions();
  sText := NormalizeSearch(SynEditOptions);
  Editor.SetHighlightSearch(sText,  SynEditOptions);
end;

procedure TSearchAndReplace.ClearHighlights();
var
  SynEditOptions: TSynSearchOptions;
begin
  SynEditOptions := GetSynEditHighlightOptions();
  Editor.SetHighlightSearch('',  SynEditOptions);
end;

procedure TSearchAndReplace.Replace(All: Boolean; Prompt: Boolean);
var
  SynEditOptions: TSynSearchOptions;
  Message: string;
begin
  SynEditOptions := GetSynEditSearchOptions(False);

  if All then
     Include(SynEditOptions, ssoReplaceAll)
  else
     Include(SynEditOptions, ssoReplace);

  if Prompt then
     Include(SynEditOptions, ssoPrompt);

  fFoundCount := Editor.SearchReplace(TextToFind, ReplaceWith, SynEditOptions);

  if All and (fFoundCount > 0) then
  begin
    Message := Format('%d replacements done.', [fFoundCount]);
    App.InfoBox(Message);
  end;

end;

procedure TSearchAndReplace.FindNext();
var
  SynEditOptions: TSynSearchOptions;
  Message: string;
  P: TPoint;
begin
  SynEditOptions := GetSynEditSearchOptions(False);
  fFoundCount := Editor.SearchReplace(TextToFind, '', SynEditOptions);

  if fFoundCount = 0 then
  begin
    Message := 'You have reached the end of the text.' + LineEnding +
               'Do you want me to search again?';
    if App.QuestionBox(Message) then
    begin
      P.X := 1; P.Y:= 0;
      Editor.CaretXY := P;
    end;
  end;
end;

procedure TSearchAndReplace.FindPrevious();
var
  SynEditOptions: TSynSearchOptions;
  Message: string;
  P: TPoint;
begin
  SynEditOptions := GetSynEditSearchOptions(True);
  fFoundCount := Editor.SearchReplace(TextToFind, '', SynEditOptions);

  if fFoundCount = 0 then
  begin
    Message := 'You have reached the beginning of the text.' + LineEnding +
               'Do you want me to search again?';
    if App.QuestionBox(Message) then
    begin
      // Move caret to end of text
      P.Y := Editor.Lines.Count;
      if P.Y < 1 then
      begin
        P.X := 0;
        P.Y := 0;
      end
      else
      begin
        P.X := Length(Editor.Lines[P.Y - 1]) + 1; // caret column is 1-based
      end;

      Editor.CaretXY := P;
    end;
  end;

end;



function TSearchAndReplace.GetSynEditSearchOptions(Backwards: Boolean): TSynSearchOptions;
begin
  Result := [ssoFindContinue];     // ssoEntireScope

  if (MatchCase) then
     Include(Result, ssoMatchCase);

  if (WholeWord) then
     Include(Result, ssoWholeWord);

  if Backwards then
     Include(Result, ssoBackwards);

  if ReplaceFlag then
     Include(Result, ssoReplace);

  if ReplaceAllFlag then
     Include(Result, ssoReplaceAll);

  if PromptOnReplace then
     Include(Result, ssoPrompt);
end;


end.

