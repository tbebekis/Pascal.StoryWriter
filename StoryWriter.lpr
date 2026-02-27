program StoryWriter;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, f_MainForm, f_CategoryListForm, f_TagListForm, f_ComponentListForm,
  f_SearchForm, f_QuickViewForm, f_NoteListForm, f_TempTextForm,
  f_StoryListForm, f_ComponentForm, f_NoteForm, f_StoryForm, f_ChapterForm,
  f_SceneForm, o_MarkDownPreview, f_TextEditorForm
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

