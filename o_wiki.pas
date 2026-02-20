unit o_Wiki;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  Generics.Collections, Generics.Defaults,
  FileUtil, LazFileUtils,
  MarkdownProcessor,
  MarkdownUtils,
  o_WikiInfo;

type
  Wiki = class
  private
    class function  P(const A, B: string): string; static;
    class procedure EnsureDir(const Dir: string); static;
    class procedure WriteTextUtf8(const FileName, Text: string); static;
    class function  ReadTextUtf8(const FileName: string): string; static;

    class procedure SafeCleanOutputFolder(const Root: string; ResultObj: TWikiBuildResult); static;

    class procedure ExtractResourceToFile(const ResName, DestFile: string); static;
    class function  LoadResourceText(const ResName: string): string; static;

    class function  HtmlEscape(const S: string): string; static;
    class function  JsonEscape(const S: string): string; static;

    class function  Slug(const Text: string): string; static;
    class function  RemoveSpaces(const S: string): string; static;
    class function  NormalizeNewlines(const S: string): string; static;
    class function  GetTail(const S: string; MaxChars: Integer): string; static;

    class function  GetComponentMarkdownPath(const ComponentsFolder, Title: string): string; static;
    class function  CollectAllTitles(Components: TObjectList<TComponentInfo>): TStringList; static;

    // markdown pipeline
    class function  RenderMarkdownToHtmlFragment(const MarkdownText: string): string; static;
    class function  RewriteImagePathsInHtml(const Html: string): string; static;
    class function  RenderComponentHtml(const MarkdownText: string): string; static;
    class function  PreprocessMarkdown(const MarkdownText: string; AllTitles: TStringList): string; static;

    // layout
    class function  WrapInLayout(const Title, SidebarHtml, HeaderHtml, ContentHtml, FooterHtml,
                                 MetaTagsHtml, TemplateHtml: string): string; static;

    class function  BuildHeaderHtml(InEnglish: Boolean): string; static;
    class function  BuildFooterHtml: string; static;
    class function  BuildSidebarHtml(Categories: TObjectList<TComponentCategory>;
                                     Tags: TObjectList<TComponentTag>): string; static;

    // auto-link (Titles + Aliases)
    class function  BuildTermMap(Components: TObjectList<TComponentInfo>): TStringList; static;
    class function  AutoLinkTermsInMarkdown(const Markdown: string; TermMap: TStringList): string; static;

    // taxonomy footer
    class function  BuildCategoryLink(const Category: string): string; static;
    class function  BuildTagLink(const Tag: string): string; static;
    class function  BuildTagsLine(Tags: TStrings): string; static;
    class function  AppendTaxonomyFooter(const Markdown, Category: string; Tags: TStrings): string; static;

    // search index / seo
    class function  StripMarkdownToText(const Markdown: string): string; static;
    class function  BuildMetaDescription(const BodyText: string): string; static;
    class function  BuildMetaTags(const Title, Description, RelativeUrl: string; Info: TWikiBuildInfo): string; static;

    class procedure WriteSearchIndexJson(const OutputFolder: string; Entries: TObjectList<TSearchIndexEntry>); static;

    // assets / images
    class procedure WriteAssets(const OutputFolder: string; ResultObj: TWikiBuildResult); static;
    class procedure CopyImages(const SourceImagesFolder, DestImagesFolder: string; ResultObj: TWikiBuildResult); static;

    // sitemap/robots
    class procedure WriteSitemapXml(const OutputFolder, SiteBaseUrl: string; RelativeUrls: TStrings; ResultObj: TWikiBuildResult); static;
    class procedure WriteRobotsTxt(const OutputFolder, SiteBaseUrl: string; ResultObj: TWikiBuildResult); static;

    // about
    class procedure GenerateAboutPage(Info: TWikiBuildInfo; const SidebarHtml, TemplateHtml: string;
                                     Entries: TObjectList<TSearchIndexEntry>; Urls: TStrings; ResultObj: TWikiBuildResult); static;

    class procedure LogLine(ResultObj: TWikiBuildResult; const S: string); static;
    class procedure AddEmitted(ResultObj: TWikiBuildResult; const RelPath: string); static;

  public
    class function Build(BuildInfo: TWikiBuildInfo): TWikiBuildResult; static;
  end;

implementation


function PosText(const SubStr, S: string): SizeInt;
begin
  Result := Pos(UpperCase(SubStr), UpperCase(S));
end;

function CompareTermsByLenDesc(List: TStringList; Index1, Index2: Integer): Integer;
var
  A, B: string;
begin
  A := List[Index1];
  B := List[Index2];

  Result := Length(B) - Length(A);      // DESC length
  if Result = 0 then
    Result := CompareText(A, B);        // stable-ish
end;

// ------------------------------------------------------------
// Global comparer functions (NOT nested) — required for TComparer
// ------------------------------------------------------------

function TermCompare(constref L, R: string): Integer;
begin
  Result := Length(R) - Length(L);
  if Result = 0 then
    Result := CompareText(L, R);
end;

function CatCompare(constref L, R: TComponentCategory): Integer;
begin
  Result := CompareText(IfThen(L<>nil, L.Name, ''), IfThen(R<>nil, R.Name, ''));
end;

function TagCompare(constref L, R: TComponentTag): Integer;
begin
  Result := CompareText(IfThen(L<>nil, L.Name, ''), IfThen(R<>nil, R.Name, ''));
end;

function CompCompare(constref L, R: TComponentInfo): Integer;
begin
  Result := CompareText(IfThen(L<>nil, L.Title, ''), IfThen(R<>nil, R.Title, ''));
end;

// ------------------------------------------------------------

class function Wiki.P(const A, B: string): string;
begin
  Result := AppendPathDelim(A) + B;
end;

class procedure Wiki.EnsureDir(const Dir: string);
begin
  if Dir = '' then Exit;
  if not DirectoryExistsUTF8(Dir) then
    ForceDirectoriesUTF8(Dir);
end;

class procedure Wiki.WriteTextUtf8(const FileName, Text: string);
var
  Fs: TFileStream;
  Bytes: RawByteString;
begin
  EnsureDir(ExtractFileDir(FileName));
  Fs := TFileStream.Create(FileName, fmCreate);
  try
    Bytes := UTF8Encode(Text);
    if Length(Bytes) > 0 then
      Fs.WriteBuffer(Bytes[1], Length(Bytes));
  finally
    Fs.Free;
  end;
end;

class function Wiki.ReadTextUtf8(const FileName: string): string;
begin
  Result := ReadFileToString(FileName);
end;

class procedure Wiki.LogLine(ResultObj: TWikiBuildResult; const S: string);
begin
  if (ResultObj <> nil) and Assigned(ResultObj.Log) then
    ResultObj.Log.Add(S);
end;

class procedure Wiki.AddEmitted(ResultObj: TWikiBuildResult; const RelPath: string);
begin
  if (ResultObj <> nil) and Assigned(ResultObj.EmittedFiles) then
    ResultObj.EmittedFiles.Add(StringReplace(RelPath, '\', '/', [rfReplaceAll]));
end;

class procedure Wiki.SafeCleanOutputFolder(const Root: string; ResultObj: TWikiBuildResult);
var
  SR: TSearchRec;
  Item: string;

  function KeepName(const Name: string): Boolean;
begin
  Result :=
    SameText(Name, '.git') or
    SameText(Name, '.github') or
    SameText(Name, '.gitignore') or
    SameText(Name, '.gitattributes');
end;

begin
  if Trim(Root) = '' then Exit;

  if not DirectoryExistsUTF8(Root) then
  begin
    EnsureDir(Root);
    LogLine(ResultObj, 'Output folder created: ' + Root);
    Exit;
  end;

  if FindFirstUTF8(P(Root, '*'), faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if KeepName(SR.Name) then Continue;

      Item := P(Root, SR.Name);
      if DirectoryExistsUTF8(Item) then
        DeleteDirectory(Item, False)
      else
        DeleteFileUTF8(Item);

    until FindNextUTF8(SR) <> 0;
  finally
    FindCloseUTF8(SR);
  end;
end;

class procedure Wiki.ExtractResourceToFile(const ResName, DestFile: string);
var
  RS: TResourceStream;
  FS: TFileStream;
begin
  EnsureDir(ExtractFileDir(DestFile));

  RS := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
  try
    FS := TFileStream.Create(DestFile, fmCreate);
    try
      FS.CopyFrom(RS, 0);
    finally
      FS.Free;
    end;
  finally
    RS.Free;
  end;
end;

class function Wiki.LoadResourceText(const ResName: string): string;
var
  RS: TResourceStream;
  SS: TStringStream;
begin
  RS := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
  try
    SS := TStringStream.Create('', TEncoding.UTF8);
    try
      SS.CopyFrom(RS, 0);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  finally
    RS.Free;
  end;
end;

class function Wiki.HtmlEscape(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

class function Wiki.JsonEscape(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9,  '\t', [rfReplaceAll]);
end;

class function Wiki.RemoveSpaces(const S: string): string;
begin
  Result := StringReplace(S, ' ', '', [rfReplaceAll]);
end;

class function Wiki.NormalizeNewlines(const S: string): string;
begin
  Result := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

class function Wiki.GetTail(const S: string; MaxChars: Integer): string;
begin
  if Length(S) <= MaxChars then Exit(S);
  Result := Copy(S, Length(S) - MaxChars + 1, MaxChars);
end;

class function Wiki.GetComponentMarkdownPath(const ComponentsFolder, Title: string): string;
var
  FileName: string;
begin
  FileName := RemoveSpaces(Title);
  if not AnsiEndsText('.md', FileName) then
    FileName := FileName + '.md';
  Result := P(ComponentsFolder, FileName);
end;

class function Wiki.Slug(const Text: string): string;
var
  I: Integer;
  C: Char;
  Lower: string;
begin
  if Text = '' then Exit('');
  Lower := LowerCase(Text);

  Result := '';
  for I := 1 to Length(Lower) do
  begin
    C := Lower[I];
    if (C in ['a'..'z','0'..'9']) then
      Result := Result + C
    else if (C in [' ', '_','-','.']) then
      Result := Result + '-';
  end;

  while Pos('--', Result) > 0 do
    Result := StringReplace(Result, '--', '-', [rfReplaceAll]);

  Result := Trim(Result);
  while (Result <> '') and (Result[1] = '-') do Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] = '-') do Delete(Result, Length(Result), 1);
end;

class function Wiki.CollectAllTitles(Components: TObjectList<TComponentInfo>): TStringList;
var
  I: Integer;
  C: TComponentInfo;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Sorted := False;
  Result.Duplicates := dupIgnore;

  if Components = nil then Exit;
  for I := 0 to Components.Count - 1 do
  begin
    C := Components[I];
    if (C <> nil) and (Trim(C.Title) <> '') then
      Result.Add(C.Title);
  end;
end;

// -------------------
// Markdown
// -------------------
class function Wiki.RenderMarkdownToHtmlFragment(const MarkdownText: string): string;
var
  Md: TMarkdownProcessor;
begin
  Md := TMarkdownProcessor.CreateDialect(mdCommonMark);
  try
    Md.UnSafe := False;
    Result := Md.process(MarkdownText);
  finally
    Md.Free;
  end;
end;

class function Wiki.RewriteImagePathsInHtml(const Html: string): string;
var
  S: string;
begin
  S := Html;
  S := StringReplace(S, 'src="../Images/', 'src="/assets/images/', [rfReplaceAll]);
  S := StringReplace(S, 'src="Images/',  'src="/assets/images/', [rfReplaceAll]);
  S := StringReplace(S, 'src="/Images/', 'src="/assets/images/', [rfReplaceAll]);
  Result := S;
end;

class function Wiki.RenderComponentHtml(const MarkdownText: string): string;
var
  Html: string;
begin
  Html := RenderMarkdownToHtmlFragment(MarkdownText);
  Html := RewriteImagePathsInHtml(Html);
  Result := '<article>' + Html + '</article>';
end;

class function Wiki.PreprocessMarkdown(const MarkdownText: string; AllTitles: TStringList): string;
var
  S, T, FileName, Target: string;
  I: Integer;
begin
  S := MarkdownText;
  if (AllTitles = nil) or (AllTitles.Count = 0) then Exit(S);

  for I := 0 to AllTitles.Count - 1 do
  begin
    T := AllTitles[I];
    if Trim(T) = '' then Continue;

    FileName := RemoveSpaces(T) + '.md';
    Target := '/components/' + Slug(T) + '.html';

    S := StringReplace(S, '(' + FileName + ')', '(' + Target + ')', [rfReplaceAll, rfIgnoreCase]);
    S := StringReplace(S, '[' + T + ']()', '[' + T + '](' + Target + ')', [rfReplaceAll, rfIgnoreCase]);
  end;

  Result := S;
end;

// -------------------
// Layout
// -------------------
class function Wiki.WrapInLayout(const Title, SidebarHtml, HeaderHtml, ContentHtml, FooterHtml,
                                MetaTagsHtml, TemplateHtml: string): string;
begin
  Result := TemplateHtml;
  Result := StringReplace(Result, '{{TITLE}}', HtmlEscape(Title), [rfReplaceAll]);
  Result := StringReplace(Result, '{{HEADER}}', HeaderHtml, [rfReplaceAll]);
  Result := StringReplace(Result, '{{SIDEBAR}}', SidebarHtml, [rfReplaceAll]);
  Result := StringReplace(Result, '{{CONTENT}}', ContentHtml, [rfReplaceAll]);
  Result := StringReplace(Result, '{{FOOTER}}', FooterHtml, [rfReplaceAll]);
  Result := StringReplace(Result, '{{META_TAGS}}', MetaTagsHtml, [rfReplaceAll]);
end;

class function Wiki.BuildHeaderHtml(InEnglish: Boolean): string;
var
  SearchPlaceholder: string;
begin
  if InEnglish then SearchPlaceholder := 'Search…' else SearchPlaceholder := 'Αναζήτηση…';

  Result :=
    '<header class="site-header">' +
      '<div class="header-left">' +
        '<button class="burger" aria-label="Menu">☰</button>' +
        '<a class="home-link" href="/index.html">Go to World</a> ' +
        '<a class="about-link" href="/about.html">About</a>' +
      '</div>' +
      '<div class="header-right">' +
        '<div class="search-box"><input id="search-input" type="search" placeholder="' + HtmlEscape(SearchPlaceholder) +
        '" autocomplete="off" /><div id="search-results" class="search-results"></div></div>' +
        '<div class="theme-toggle" role="group" aria-label="Theme">' +
          '<button class="theme-btn" data-mode="light" title="Light">☀️</button>' +
          '<button class="theme-btn" data-mode="dark" title="Dark">🌙</button>' +
          '<button class="theme-btn" data-mode="auto" title="Auto">🖥️</button>' +
        '</div>' +
        '<a class="buy-btn" href="https://www.amazon.com/dp/B0G2MXJ2RG" target="_blank">Buy the Book</a>' +
      '</div>' +
    '</header>';
end;

class function Wiki.BuildFooterHtml: string;
begin
  Result :=
    '<footer class="site-footer">' +
      '<div class="footer-right"><a class="buy-footer" href="https://www.amazon.com/dp/B0G2MXJ2RG" target="_blank">Buy the Book</a></div>' +
      '<div><hr></div>' +
      '<div class="footer-left">Generated by tb.StoryWriter Wiki © Theo Bebekis</div>' +
      '<div><p><a href="mailto:teo.bebekis@gmail.com">Official Author Email</a></p></div>' +
    '</footer>';
end;

class function Wiki.BuildSidebarHtml(Categories: TObjectList<TComponentCategory>;
                                    Tags: TObjectList<TComponentTag>): string;
var
  Sb: TStringBuilder;
  Cats: TObjectList<TComponentCategory>;
  Tgs: TObjectList<TComponentTag>;
  I: Integer;
  Cat: TComponentCategory;
  Tag: TComponentTag;
begin
  Sb := TStringBuilder.Create;
  try
    Sb.Append('<div class="accordion">');

    Sb.Append('<section class="acc"><button class="acc-h" data-target="cats">Categories</button><div id="cats" class="acc-b">');
    Sb.Append('<input type="text" class="quick-filter" placeholder="Filter categories..." oninput="window.__filter(this,''cats'')">');
    Sb.Append('<ul>');

    Cats := TObjectList<TComponentCategory>.Create(False);
    try
      if Categories <> nil then
        for I := 0 to Categories.Count - 1 do Cats.Add(Categories[I]);

      Cats.Sort(TComparer<TComponentCategory>.Construct(CatCompare));

      for I := 0 to Cats.Count - 1 do
      begin
        Cat := Cats[I];
        if (Cat = nil) or (Trim(Cat.Name) = '') then Continue;

        Sb.Append('<li><a href="/categories/');
        Sb.Append(HtmlEscape(Slug(Cat.Name)));
        Sb.Append('.html">');
        Sb.Append(HtmlEscape(Cat.Name));
        Sb.Append('</a></li>');
      end;
    finally
      Cats.Free;
    end;

    Sb.Append('</ul></div></section>');

    Sb.Append('<section class="acc"><button class="acc-h" data-target="tags">Tags</button><div id="tags" class="acc-b">');
    Sb.Append('<input type="text" class="quick-filter" placeholder="Filter tags..." oninput="window.__filter(this,''tags'')">');
    Sb.Append('<ul>');

    Tgs := TObjectList<TComponentTag>.Create(False);
    try
      if Tags <> nil then
        for I := 0 to Tags.Count - 1 do Tgs.Add(Tags[I]);

      Tgs.Sort(TComparer<TComponentTag>.Construct(TagCompare));

      for I := 0 to Tgs.Count - 1 do
      begin
        Tag := Tgs[I];
        if (Tag = nil) or (Trim(Tag.Name) = '') then Continue;

        Sb.Append('<li><a href="/tags/');
        Sb.Append(HtmlEscape(Slug(Tag.Name)));
        Sb.Append('.html">');
        Sb.Append(HtmlEscape(Tag.Name));
        Sb.Append('</a></li>');
      end;
    finally
      Tgs.Free;
    end;

    Sb.Append('</ul></div></section>');
    Sb.Append('</div>');

    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// -------------------
// Auto-linking (safe scan, protected tokens)
// TermMap: "term=url" in TStringList (Name=Value style)
// -------------------
class function Wiki.BuildTermMap(Components: TObjectList<TComponentInfo>): TStringList;
var
  I, J: Integer;
  C: TComponentInfo;
  Term, Url: string;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Sorted := False;

  if Components = nil then Exit;

  for I := 0 to Components.Count - 1 do
  begin
    C := Components[I];
    if (C = nil) or (Trim(C.Title) = '') then Continue;

    Url := '/components/' + Slug(C.Title) + '.html';

    Term := C.Title;
    if Result.IndexOfName(Term) < 0 then
      Result.Add(Term + '=' + Url);

    if C.AliasList <> nil then
      for J := 0 to C.AliasList.Count - 1 do
      begin
        Term := Trim(C.AliasList[J]);
        if Term = '' then Continue;
        if Result.IndexOfName(Term) < 0 then
          Result.Add(Term + '=' + Url);
      end;
  end;
end;

class function Wiki.AutoLinkTermsInMarkdown(const Markdown: string; TermMap: TStringList): string;
var
  Tokens: TStringList;
  Work: string;
  Terms: TStringList;
  I: Integer;

  function ProtectFence(const Input, Fence: string): string;
  var
    S: string;
    P1, P2: SizeInt;
    Tok: string;
  begin
    S := Input;
    while True do
    begin
      P1 := Pos(Fence, S);
      if P1 = 0 then Break;
      P2 := PosEx(Fence, S, P1 + Length(Fence));
      if P2 = 0 then Break;

      Tok := Copy(S, P1, (P2 + Length(Fence) - P1));
      Tokens.Add(Tok);
      S := Copy(S, 1, P1-1) + '@@TOKEN_' + IntToStr(Tokens.Count-1) + '@@' + Copy(S, P2 + Length(Fence), MaxInt);
    end;
    Result := S;
  end;

  function ProtectInlineCode(const Input: string): string;
  var
    S: string;
    P1, P2: SizeInt;
    Tok: string;
  begin
    S := Input;
    while True do
    begin
      P1 := Pos('`', S);
      if P1 = 0 then Break;
      P2 := PosEx('`', S, P1 + 1);
      if P2 = 0 then Break;

      Tok := Copy(S, P1, P2 - P1 + 1);
      Tokens.Add(Tok);
      S := Copy(S, 1, P1-1) + '@@TOKEN_' + IntToStr(Tokens.Count-1) + '@@' + Copy(S, P2+1, MaxInt);
    end;
    Result := S;
  end;

  function ProtectMdLinks(const Input: string): string;
  var
    S: string;
    P1, P2, P3: SizeInt;
    Tok: string;
  begin
    S := Input;
    while True do
    begin
      P1 := Pos('[', S);
      if P1 = 0 then Break;

      if (P1 > 1) and (S[P1-1] = '!') then Dec(P1);

      P2 := PosEx('](', S, P1);
      if P2 = 0 then Break;

      P3 := PosEx(')', S, P2 + 2);
      if P3 = 0 then Break;

      Tok := Copy(S, P1, P3 - P1 + 1);
      Tokens.Add(Tok);
      S := Copy(S, 1, P1-1) + '@@TOKEN_' + IntToStr(Tokens.Count-1) + '@@' + Copy(S, P3+1, MaxInt);
    end;
    Result := S;
  end;

  function Restore(const Input: string): string;
  var
    S: string;
    P1, P2: SizeInt;
    IdxStr: string;
    Idx: Integer;
  begin
    S := Input;
    while True do
    begin
      P1 := Pos('@@TOKEN_', S);
      if P1 = 0 then Break;
      P2 := PosEx('@@', S, P1 + 8);
      if P2 = 0 then Break;

      IdxStr := Copy(S, P1 + 8, P2 - (P1 + 8));
      Idx := StrToIntDef(IdxStr, -1);

      if (Idx >= 0) and (Idx < Tokens.Count) then
        S := Copy(S, 1, P1-1) + Tokens[Idx] + Copy(S, P2+2, MaxInt)
      else
        S := Copy(S, 1, P1-1) + Copy(S, P1, (P2+2)-P1) + Copy(S, P2+2, MaxInt);
    end;
    Result := S;
  end;

  function IsWordChar(const Ch: Char): Boolean;
  begin
    Result := (Ch in ['A'..'Z','a'..'z','0'..'9','_']) or (Ord(Ch) > 127);
  end;

  function FindInsensitive(const Haystack, Needle: string; StartPos: SizeInt): SizeInt;
  begin
    Result := PosEx(LowerCase(Needle), LowerCase(Haystack), StartPos);
  end;

  function ReplaceTerms(const Input: string): string;
  var
    S, Term, Url: string;
    PosFound: SizeInt;
    BeforeCh, AfterCh: Char;
    LTerm: SizeInt;
    StartPos: SizeInt;
    TermShown: string;
    I: Integer;
  begin
    S := Input;

    for I := 0 to Terms.Count - 1 do
    begin
      Term := Terms[I];
      Url := TermMap.Values[Term];
      if (Trim(Term) = '') or (Url = '') then Continue;

      StartPos := 1;
      LTerm := Length(Term);

      while True do
      begin
        PosFound := FindInsensitive(S, Term, StartPos);
        if PosFound = 0 then Break;

        if PosFound = 1 then BeforeCh := #0 else BeforeCh := S[PosFound-1];
        if PosFound + LTerm > Length(S) then AfterCh := #0 else AfterCh := S[PosFound + LTerm];

        if (BeforeCh <> #0) and IsWordChar(BeforeCh) then
        begin
          StartPos := PosFound + LTerm;
          Continue;
        end;
        if (AfterCh <> #0) and IsWordChar(AfterCh) then
        begin
          StartPos := PosFound + LTerm;
          Continue;
        end;

        // skip if looks already inside markdown link text
        if (PosFound > 1) and (S[PosFound-1] = '[') then
        begin
          StartPos := PosFound + LTerm;
          Continue;
        end;

        TermShown := Copy(S, PosFound, LTerm);
        S := Copy(S, 1, PosFound-1) + '[' + TermShown + '](' + Url + ')' +
             Copy(S, PosFound + LTerm, MaxInt);

        StartPos := PosFound + Length(Url) + LTerm + 4;
      end;
    end;

    Result := S;
  end;

begin
  if Markdown = '' then Exit('');
  if (TermMap = nil) or (TermMap.Count = 0) then Exit(Markdown);

  Tokens := TStringList.Create;
  Terms := TStringList.Create;
  try
    for I := 0 to TermMap.Count - 1 do
      if Trim(TermMap.Names[I]) <> '' then
        Terms.Add(TermMap.Names[I]);

    //Terms.Sort(TComparer<string>.Construct(TermCompare));
    Terms.CustomSort(CompareTermsByLenDesc);

    Work := Markdown;
    Work := ProtectFence(Work, '```');
    Work := ProtectFence(Work, '~~~');
    Work := ProtectInlineCode(Work);
    Work := ProtectMdLinks(Work);

    Work := ReplaceTerms(Work);
    Result := Restore(Work);
  finally
    Terms.Free;
    Tokens.Free;
  end;
end;

// -------------------
// Taxonomy
// -------------------
class function Wiki.BuildCategoryLink(const Category: string): string;
var
  Lbl: string;
begin
  Lbl := Trim(Category);
  if Lbl = '' then Exit('');
  Result := '[' + Lbl + '](/categories/' + Slug(Lbl) + '.html)';
end;

class function Wiki.BuildTagLink(const Tag: string): string;
var
  Lbl: string;
begin
  Lbl := Trim(Tag);
  if Lbl = '' then Exit('');
  Result := '[' + Lbl + '](/tags/' + Slug(Lbl) + '.html)';
end;

class function Wiki.BuildTagsLine(Tags: TStrings): string;
var
  I: Integer;
  First: Boolean;
  Lbl: string;
begin
  Result := '';
  if Tags = nil then Exit;

  First := True;
  for I := 0 to Tags.Count - 1 do
  begin
    Lbl := Trim(Tags[I]);
    if Lbl = '' then Continue;
    if not First then Result := Result + ', ';
    Result := Result + BuildTagLink(Lbl);
    First := False;
  end;
end;

class function Wiki.AppendTaxonomyFooter(const Markdown, Category: string; Tags: TStrings): string;
var
  Norm, Tail, TagsLine: string;
  HasCategory, HasTags: Boolean;
  Sb: TStringBuilder;
begin
  Norm := TrimRight(NormalizeNewlines(Markdown));
  Tail := GetTail(Norm, 400);

  HasCategory := (PosText('Category:', Tail) > 0);
  HasTags := (PosText('Tags:', Tail) > 0);

  Sb := TStringBuilder.Create;
  try
    Sb.Append(Norm);
    Sb.Append(#10#10);

    if (Trim(Category) <> '') and (not HasCategory) then
    begin
      Sb.Append('Category: ');
      Sb.Append(BuildCategoryLink(Category));
      Sb.Append(#10);
    end;

    TagsLine := BuildTagsLine(Tags);
    if (Trim(TagsLine) <> '') and (not HasTags) then
    begin
      Sb.Append('Tags: ');
      Sb.Append(TagsLine);
      Sb.Append(#10);
    end;

    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

// -------------------
// Index text / meta
// -------------------
class function Wiki.StripMarkdownToText(const Markdown: string): string;
var
  S: string;
begin
  S := NormalizeNewlines(Markdown);

  // crude but ok for search index
  S := StringReplace(S, '```', ' ', [rfReplaceAll]);
  S := StringReplace(S, '~~~', ' ', [rfReplaceAll]);
  S := StringReplace(S, '`', ' ', [rfReplaceAll]);

  S := StringReplace(S, '![', ' ', [rfReplaceAll]);
  S := StringReplace(S, '](', ' ', [rfReplaceAll]);
  S := StringReplace(S, ')', ' ', [rfReplaceAll]);
  S := StringReplace(S, '[', '', [rfReplaceAll]);
  S := StringReplace(S, ']', '', [rfReplaceAll]);

  S := StringReplace(S, '|', ' ', [rfReplaceAll]);
  while Pos('  ', S) > 0 do
    S := StringReplace(S, '  ', ' ', [rfReplaceAll]);

  Result := Trim(S);
end;

class function Wiki.BuildMetaDescription(const BodyText: string): string;
var
  S: string;
const
  MaxLen = 160;
begin
  S := Trim(BodyText);
  while Pos('  ', S) > 0 do
    S := StringReplace(S, '  ', ' ', [rfReplaceAll]);

  if S = '' then Exit('');
  if Length(S) <= MaxLen then Exit(S);
  Result := Trim(Copy(S, 1, MaxLen)) + '…';
end;

class function Wiki.BuildMetaTags(const Title, Description, RelativeUrl: string; Info: TWikiBuildInfo): string;
var
  BaseUrl, CanonicalUrl, ImgUrl, Desc, Rel: string;
  Sb: TStringBuilder;
  Prefix: string;
begin
  Rel := RelativeUrl;
  if Trim(Rel) = '' then Rel := '/';

  BaseUrl := '';
  if (Info <> nil) then BaseUrl := Trim(Info.SiteBaseUrl);
  if (BaseUrl <> '') and (BaseUrl[Length(BaseUrl)] = '/') then
    Delete(BaseUrl, Length(BaseUrl), 1);

  if BaseUrl = '' then CanonicalUrl := Rel else CanonicalUrl := BaseUrl + Rel;

  Prefix := 'Author: Theo Bebekis, Title: The Corp of the World, Category: Books';
  Desc := Trim(Description);
  if Desc <> '' then Prefix := Prefix + ', Description: ' + Desc;
  Desc := Prefix;

  Sb := TStringBuilder.Create;
  try
    if Desc <> '' then
    begin
      Sb.Append('<meta name="description" content="');
      Sb.Append(HtmlEscape(Desc));
      Sb.Append('" />');
    end;

    Sb.Append('<link rel="canonical" href="');
    Sb.Append(HtmlEscape(CanonicalUrl));
    Sb.Append('" />');

    Sb.Append('<meta property="og:type" content="website" />');

    Sb.Append('<meta property="og:title" content="');
    Sb.Append(HtmlEscape(Title));
    Sb.Append('" />');

    if Desc <> '' then
    begin
      Sb.Append('<meta property="og:description" content="');
      Sb.Append(HtmlEscape(Desc));
      Sb.Append('" />');
    end;

    Sb.Append('<meta property="og:url" content="');
    Sb.Append(HtmlEscape(CanonicalUrl));
    Sb.Append('" />');

    ImgUrl := '';
    if (Info <> nil) and (Trim(Info.DefaultSocialImageUrl) <> '') then
    begin
      ImgUrl := Trim(Info.DefaultSocialImageUrl);
      if (BaseUrl <> '') and (PosText('http', ImgUrl) <> 1) then
      begin
        if (ImgUrl <> '') and (ImgUrl[1] <> '/') then ImgUrl := '/' + ImgUrl;
        ImgUrl := BaseUrl + ImgUrl;
      end;
    end;

    if ImgUrl <> '' then
    begin
      Sb.Append('<meta property="og:image" content="');
      Sb.Append(HtmlEscape(ImgUrl));
      Sb.Append('" />');

      Sb.Append('<meta name="twitter:card" content="summary_large_image" />');

      Sb.Append('<meta name="twitter:title" content="');
      Sb.Append(HtmlEscape(Title));
      Sb.Append('" />');

      if Desc <> '' then
      begin
        Sb.Append('<meta name="twitter:description" content="');
        Sb.Append(HtmlEscape(Desc));
        Sb.Append('" />');
      end;

      Sb.Append('<meta name="twitter:image" content="');
      Sb.Append(HtmlEscape(ImgUrl));
      Sb.Append('" />');
    end;

    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

class procedure Wiki.WriteSearchIndexJson(const OutputFolder: string; Entries: TObjectList<TSearchIndexEntry>);
var
  Sb: TStringBuilder;
  I, J: Integer;
  E: TSearchIndexEntry;
begin
  if Entries = nil then Exit;

  Sb := TStringBuilder.Create;
  try
    Sb.Append('[');

    for I := 0 to Entries.Count - 1 do
    begin
      E := Entries[I];
      if E = nil then Continue;

      if Length(E.Body) > 120000 then
        E.Body := Copy(E.Body, 1, 120000);

      if I > 0 then Sb.Append(',');

      Sb.Append('{');
      Sb.Append('"id":"'); Sb.Append(JsonEscape(E.Id)); Sb.Append('",');
      Sb.Append('"title":"'); Sb.Append(JsonEscape(E.Title)); Sb.Append('",');
      Sb.Append('"category":"'); Sb.Append(JsonEscape(E.Category)); Sb.Append('",');
      Sb.Append('"url":"'); Sb.Append(JsonEscape(E.Url)); Sb.Append('",');

      Sb.Append('"aliases":[');
      if (E.Aliases <> nil) and (E.Aliases.Count > 0) then
        for J := 0 to E.Aliases.Count - 1 do
        begin
          if J > 0 then Sb.Append(',');
          Sb.Append('"'); Sb.Append(JsonEscape(E.Aliases[J])); Sb.Append('"');
        end;
      Sb.Append('],');

      Sb.Append('"tags":[');
      if (E.Tags <> nil) and (E.Tags.Count > 0) then
        for J := 0 to E.Tags.Count - 1 do
        begin
          if J > 0 then Sb.Append(',');
          Sb.Append('"'); Sb.Append(JsonEscape(E.Tags[J])); Sb.Append('"');
        end;
      Sb.Append('],');

      Sb.Append('"body":"'); Sb.Append(JsonEscape(E.Body)); Sb.Append('"');
      Sb.Append('}');
    end;

    Sb.Append(']');
    WriteTextUtf8(P(OutputFolder, 'search-index.json'), Sb.ToString);
  finally
    Sb.Free;
  end;
end;

// -------------------
// Assets / Images / SEO files
// -------------------
class procedure Wiki.WriteAssets(const OutputFolder: string; ResultObj: TWikiBuildResult);
begin
  ExtractResourceToFile('WIKI_CSS', P(P(P(OutputFolder, 'assets'), 'css'), 'wiki.css'));
  ExtractResourceToFile('WIKI_JS',  P(P(P(OutputFolder, 'assets'), 'js'),  'wiki.js'));
  AddEmitted(ResultObj, 'assets/css/wiki.css');
  AddEmitted(ResultObj, 'assets/js/wiki.js');
end;

class procedure Wiki.CopyImages(const SourceImagesFolder, DestImagesFolder: string; ResultObj: TWikiBuildResult);
var
  Files: TStringList;
  I: Integer;
  Src, Rel, Dst: string;
begin
  if (Trim(SourceImagesFolder) = '') or (not DirectoryExistsUTF8(SourceImagesFolder)) then
  begin
    LogLine(ResultObj, 'Images folder not found: ' + SourceImagesFolder);
    Exit;
  end;

  EnsureDir(DestImagesFolder);

  Files := TStringList.Create;
  try
    FindAllFiles(Files, SourceImagesFolder, '*', True);
    for I := 0 to Files.Count - 1 do
    begin
      Src := Files[I];
      Rel := ExtractRelativepath(IncludeTrailingPathDelimiter(SourceImagesFolder), Src);
      Rel := StringReplace(Rel, '\', '/', [rfReplaceAll]);

      Dst := P(DestImagesFolder, Rel);
      EnsureDir(ExtractFileDir(Dst));
      CopyFile(Src, Dst, [cffOverwriteFile]);

      AddEmitted(ResultObj, 'assets/images/' + Rel);
    end;
  finally
    Files.Free;
  end;
end;

class procedure Wiki.WriteSitemapXml(const OutputFolder, SiteBaseUrl: string; RelativeUrls: TStrings; ResultObj: TWikiBuildResult);
var
  BaseUrl: string;
  Sb: TStringBuilder;
  I: Integer;
  Rel, Loc: string;
  Seen: TStringList;
begin
  if (RelativeUrls = nil) or (RelativeUrls.Count = 0) then Exit;

  BaseUrl := Trim(SiteBaseUrl);
  if (BaseUrl <> '') and (BaseUrl[Length(BaseUrl)] = '/') then
    Delete(BaseUrl, Length(BaseUrl), 1);

  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    Seen.Sorted := True;
    Seen.Duplicates := dupIgnore;

    Sb := TStringBuilder.Create;
    try
      Sb.Append('<?xml version="1.0" encoding="UTF-8"?>'#10);
      Sb.Append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'#10);

      for I := 0 to RelativeUrls.Count - 1 do
      begin
        Rel := Trim(RelativeUrls[I]);
        if Rel = '' then Continue;
        if Seen.IndexOf(Rel) >= 0 then Continue;
        Seen.Add(Rel);

        if BaseUrl = '' then Loc := Rel else Loc := BaseUrl + Rel;

        Sb.Append('  <url><loc>');
        Sb.Append(HtmlEscape(Loc));
        Sb.Append('</loc></url>'#10);
      end;

      Sb.Append('</urlset>'#10);
      WriteTextUtf8(P(OutputFolder, 'sitemap.xml'), Sb.ToString);
      AddEmitted(ResultObj, 'sitemap.xml');
    finally
      Sb.Free;
    end;
  finally
    Seen.Free;
  end;
end;

class procedure Wiki.WriteRobotsTxt(const OutputFolder, SiteBaseUrl: string; ResultObj: TWikiBuildResult);
var
  BaseUrl: string;
  Sb: TStringBuilder;
begin
  BaseUrl := Trim(SiteBaseUrl);
  if (BaseUrl <> '') and (BaseUrl[Length(BaseUrl)] = '/') then
    Delete(BaseUrl, Length(BaseUrl), 1);

  Sb := TStringBuilder.Create;
  try
    Sb.Append('User-agent: *'#10);
    Sb.Append('Allow: /'#10);

    if BaseUrl <> '' then
    begin
      Sb.Append('Sitemap: ');
      Sb.Append(BaseUrl);
      Sb.Append('/sitemap.xml'#10);
    end
    else
      Sb.Append('Sitemap: /sitemap.xml'#10);

    WriteTextUtf8(P(OutputFolder, 'robots.txt'), Sb.ToString);
    AddEmitted(ResultObj, 'robots.txt');
  finally
    Sb.Free;
  end;
end;

// -------------------
// About
// -------------------
class procedure Wiki.GenerateAboutPage(Info: TWikiBuildInfo; const SidebarHtml, TemplateHtml: string;
                                      Entries: TObjectList<TSearchIndexEntry>; Urls: TStrings; ResultObj: TWikiBuildResult);
var
  MdPath, Md, BodyText, MetaDesc, MetaTags, Html, Page: string;
  OutPath: string;
  E: TSearchIndexEntry;
begin
  if Info = nil then Exit;

  MdPath := P(Info.ComponentsFolderPath, 'About.md');
  if not FileExistsUTF8(MdPath) then Exit;

  Md := ReadTextUtf8(MdPath);
  BodyText := StripMarkdownToText(Md);
  MetaDesc := BuildMetaDescription(BodyText);

  Html := RenderComponentHtml(Md);
  MetaTags := BuildMetaTags('About the Author', MetaDesc, '/about.html', Info);

  Page := WrapInLayout('About the Author', SidebarHtml, BuildHeaderHtml(Info.InEnglish), Html, BuildFooterHtml, MetaTags, TemplateHtml);

  OutPath := P(Info.OutputFolderPath, 'about.html');
  WriteTextUtf8(OutPath, Page);
  AddEmitted(ResultObj, 'about.html');

  if Urls <> nil then Urls.Add('/about.html');

  if Entries <> nil then
  begin
    E := TSearchIndexEntry.Create;
    E.Id := 'about';
    E.Title := 'About the Author';
    E.Body := BodyText;
    E.Url := '/about.html';
    E.Category := '';
    Entries.Add(E);
  end;
end;

// ===================
// MAIN BUILD
// ===================
class function Wiki.Build(BuildInfo: TWikiBuildInfo): TWikiBuildResult;
var
  TemplateHtml, SidebarHtml: string;
  TermMap: TStringList;
  AllTitles: TStringList;

  SearchEntries: TObjectList<TSearchIndexEntry>;
  SitemapUrls: TStringList;

  OutputFolder: string;

  WorldMdPath, Md, MdForBody, Html, Page, BodyText, MetaDesc, MetaTags: string;
  WorldTitle: string;
  OutPath, RelUrl: string;

  Comps: TObjectList<TComponentInfo>;
  Cats: TObjectList<TComponentCategory>;
  Tags: TObjectList<TComponentTag>;
  Items: TObjectList<TComponentInfo>;

  I, J: Integer;
  Comp: TComponentInfo;
  Cat: TComponentCategory;
  Tag: TComponentTag;

  E: TSearchIndexEntry;

begin
  Result := TWikiBuildResult.Create;
  LogLine(Result, 'Building...');

  if BuildInfo = nil then
  begin
    LogLine(Result, 'ERROR: BuildInfo is null.');
    Exit;
  end;

  OutputFolder := BuildInfo.OutputFolderPath;
  if Trim(OutputFolder) = '' then
  begin
    LogLine(Result, 'ERROR: OutputFolderPath is empty.');
    Exit;
  end;

  SafeCleanOutputFolder(OutputFolder, Result);

  EnsureDir(OutputFolder);
  EnsureDir(P(OutputFolder, 'components'));
  EnsureDir(P(OutputFolder, 'categories'));
  EnsureDir(P(OutputFolder, 'tags'));
  EnsureDir(P(OutputFolder, 'assets'));
  EnsureDir(P(P(OutputFolder, 'assets'), 'css'));
  EnsureDir(P(P(OutputFolder, 'assets'), 'js'));
  EnsureDir(P(P(OutputFolder, 'assets'), 'images'));

  AllTitles := CollectAllTitles(BuildInfo.Components);
  TermMap := BuildTermMap(BuildInfo.Components);
  SidebarHtml := BuildSidebarHtml(BuildInfo.Categories, BuildInfo.Tags);

  WriteAssets(OutputFolder, Result);
  TemplateHtml := LoadResourceText('WIKI_HTML');

  SearchEntries := TObjectList<TSearchIndexEntry>.Create(True);
  SitemapUrls := TStringList.Create;
  try
    // world
    WorldMdPath := GetComponentMarkdownPath(BuildInfo.ComponentsFolderPath, BuildInfo.WorldComponentTitle);
    if not FileExistsUTF8(WorldMdPath) then
    begin
      LogLine(Result, 'World markdown not found: ' + WorldMdPath);
    end
    else
    begin
      Md := ReadTextUtf8(WorldMdPath);
      MdForBody := Md;

      Md := AutoLinkTermsInMarkdown(Md, TermMap);
      Md := PreprocessMarkdown(Md, AllTitles);

      Html := RenderComponentHtml(Md);
      Html := '<div class="buy-block"><a href="https://www.amazon.com/dp/B0G2MXJ2RG" target="_blank">Buy The Corp of the World on Amazon</a></div>' + Html;

      WorldTitle := BuildInfo.WorldComponentTitle + ' – World';
      BodyText := StripMarkdownToText(MdForBody);
      MetaDesc := BuildMetaDescription(BodyText);
      MetaTags := BuildMetaTags(WorldTitle, MetaDesc, '/index.html', BuildInfo);

      Page := WrapInLayout(WorldTitle, SidebarHtml, BuildHeaderHtml(BuildInfo.InEnglish), Html, BuildFooterHtml, MetaTags, TemplateHtml);

      OutPath := P(OutputFolder, 'index.html');
      WriteTextUtf8(OutPath, Page);
      AddEmitted(Result, 'index.html');

      E := TSearchIndexEntry.Create;
      E.Id := 'index';
      E.Title := BuildInfo.WorldComponentTitle;
      E.Body := BodyText;
      E.Url := '/index.html';
      E.Category := '';
      SearchEntries.Add(E);

      SitemapUrls.Add('/index.html');
    end;

    // about
    GenerateAboutPage(BuildInfo, SidebarHtml, TemplateHtml, SearchEntries, SitemapUrls, Result);

    // components
    Comps := TObjectList<TComponentInfo>.Create(False);
    try
      if BuildInfo.Components <> nil then
        for I := 0 to BuildInfo.Components.Count - 1 do Comps.Add(BuildInfo.Components[I]);

      Comps.Sort(TComparer<TComponentInfo>.Construct(CompCompare));

      for I := 0 to Comps.Count - 1 do
      begin
        Comp := Comps[I];
        if (Comp = nil) or (Trim(Comp.Title) = '') then Continue;

        WorldMdPath := GetComponentMarkdownPath(BuildInfo.ComponentsFolderPath, Comp.Title);
        if not FileExistsUTF8(WorldMdPath) then
        begin
          LogLine(Result, 'Missing component markdown: ' + WorldMdPath);
          Continue;
        end;

        Md := ReadTextUtf8(WorldMdPath);
        MdForBody := Md;

        Md := AutoLinkTermsInMarkdown(Md, TermMap);
        Md := PreprocessMarkdown(Md, AllTitles);
        Md := AppendTaxonomyFooter(Md, Comp.Category, Comp.TagList);

        Html := RenderComponentHtml(Md);
        Html := '<div class="buy-block"><a href="https://www.amazon.com/dp/B0G2MXJ2RG" target="_blank">Buy The Corp of the World</a></div>' + Html;

        BodyText := StripMarkdownToText(MdForBody);
        RelUrl := '/components/' + Slug(Comp.Title) + '.html';
        MetaDesc := BuildMetaDescription(BodyText);
        MetaTags := BuildMetaTags(Comp.Title, MetaDesc, RelUrl, BuildInfo);

        Page := WrapInLayout(Comp.Title, SidebarHtml, BuildHeaderHtml(BuildInfo.InEnglish), Html, BuildFooterHtml, MetaTags, TemplateHtml);

        OutPath := P(P(OutputFolder, 'components'), Slug(Comp.Title) + '.html');
        WriteTextUtf8(OutPath, Page);
        AddEmitted(Result, 'components/' + Slug(Comp.Title) + '.html');

        E := TSearchIndexEntry.Create;
        E.Id := Slug(Comp.Title);
        E.Title := Comp.Title;
        if Comp.AliasList <> nil then E.Aliases.AddStrings(Comp.AliasList);
        if Comp.TagList <> nil then E.Tags.AddStrings(Comp.TagList);
        E.Body := BodyText;
        E.Url := RelUrl;
        E.Category := Comp.Category;
        SearchEntries.Add(E);

        SitemapUrls.Add(RelUrl);
      end;
    finally
      Comps.Free;
    end;

    // categories
    Cats := TObjectList<TComponentCategory>.Create(False);
    try
      if BuildInfo.Categories <> nil then
        for I := 0 to BuildInfo.Categories.Count - 1 do Cats.Add(BuildInfo.Categories[I]);

      Cats.Sort(TComparer<TComponentCategory>.Construct(CatCompare));

      for I := 0 to Cats.Count - 1 do
      begin
        Cat := Cats[I];
        if (Cat = nil) or (Trim(Cat.Name) = '') then Continue;

        Items := TObjectList<TComponentInfo>.Create(False);
        try
          if Cat.Components <> nil then
            for J := 0 to Cat.Components.Count - 1 do Items.Add(Cat.Components[J]);

          Items.Sort(TComparer<TComponentInfo>.Construct(CompCompare));

          Html := '<article><h1>' + HtmlEscape(Cat.Name) + '</h1><ul>';
          for J := 0 to Items.Count - 1 do
          begin
            Comp := Items[J];
            if (Comp = nil) or (Trim(Comp.Title) = '') then Continue;
            Html := Html + '<li><a href="/components/' + HtmlEscape(Slug(Comp.Title)) + '.html">' +
                          HtmlEscape(Comp.Title) + '</a></li>';
          end;
          Html := Html + '</ul></article>';
        finally
          Items.Free;
        end;

        RelUrl := '/categories/' + Slug(Cat.Name) + '.html';
        if BuildInfo.InEnglish then
          MetaDesc := 'Browse components in category ' + Cat.Name + ' in the world wiki.'
        else
          MetaDesc := 'Κατηγορία ' + Cat.Name + ' στο wiki του κόσμου.';

        MetaTags := BuildMetaTags('Category: ' + Cat.Name, MetaDesc, RelUrl, BuildInfo);
        Page := WrapInLayout('Category: ' + Cat.Name, SidebarHtml, BuildHeaderHtml(BuildInfo.InEnglish), Html, BuildFooterHtml, MetaTags, TemplateHtml);

        OutPath := P(P(OutputFolder, 'categories'), Slug(Cat.Name) + '.html');
        WriteTextUtf8(OutPath, Page);
        AddEmitted(Result, 'categories/' + Slug(Cat.Name) + '.html');
        SitemapUrls.Add(RelUrl);
      end;
    finally
      Cats.Free;
    end;

    // tags
    if BuildInfo.GenerateTagPages then
    begin
      Tags := TObjectList<TComponentTag>.Create(False);
      try
        if BuildInfo.Tags <> nil then
          for I := 0 to BuildInfo.Tags.Count - 1 do Tags.Add(BuildInfo.Tags[I]);

        Tags.Sort(TComparer<TComponentTag>.Construct(TagCompare));

        for I := 0 to Tags.Count - 1 do
        begin
          Tag := Tags[I];
          if (Tag = nil) or (Trim(Tag.Name) = '') then Continue;

          Items := TObjectList<TComponentInfo>.Create(False);
          try
            if Tag.Components <> nil then
              for J := 0 to Tag.Components.Count - 1 do Items.Add(Tag.Components[J]);

            Items.Sort(TComparer<TComponentInfo>.Construct(CompCompare));

            Html := '<article><h1>Tag: ' + HtmlEscape(Tag.Name) + '</h1><ul>';
            for J := 0 to Items.Count - 1 do
            begin
              Comp := Items[J];
              if (Comp = nil) or (Trim(Comp.Title) = '') then Continue;
              Html := Html + '<li><a href="/components/' + HtmlEscape(Slug(Comp.Title)) + '.html">' +
                            HtmlEscape(Comp.Title) + '</a></li>';
            end;
            Html := Html + '</ul></article>';
          finally
            Items.Free;
          end;

          RelUrl := '/tags/' + Slug(Tag.Name) + '.html';
          if BuildInfo.InEnglish then
            MetaDesc := 'Browse components with tag ' + Tag.Name + ' in the world wiki.'
          else
            MetaDesc := 'Tag ' + Tag.Name + ' στο wiki του κόσμου.';

          MetaTags := BuildMetaTags('Tag: ' + Tag.Name, MetaDesc, RelUrl, BuildInfo);
          Page := WrapInLayout('Tag: ' + Tag.Name, SidebarHtml, BuildHeaderHtml(BuildInfo.InEnglish), Html, BuildFooterHtml, MetaTags, TemplateHtml);

          OutPath := P(P(OutputFolder, 'tags'), Slug(Tag.Name) + '.html');
          WriteTextUtf8(OutPath, Page);
          AddEmitted(Result, 'tags/' + Slug(Tag.Name) + '.html');
          SitemapUrls.Add(RelUrl);
        end;
      finally
        Tags.Free;
      end;
    end;

    CopyImages(BuildInfo.ImagesFolderPath, P(P(OutputFolder, 'assets'), 'images'), Result);

    WriteSitemapXml(OutputFolder, BuildInfo.SiteBaseUrl, SitemapUrls, Result);
    WriteRobotsTxt(OutputFolder, BuildInfo.SiteBaseUrl, Result);

    WriteSearchIndexJson(OutputFolder, SearchEntries);
    AddEmitted(Result, 'search-index.json');

    LogLine(Result, 'Done.');
  finally
    TermMap.Free;
    AllTitles.Free;
    SearchEntries.Free;
    SitemapUrls.Free;
  end;
end;

end.
