unit APIUnit;

interface

implementation

uses logUnit, FileView;

procedure log(text : string);
begin
  LogUnit.LogForm.log(text);
end;

procedure sendTestRequest();
begin
  with FileViewForm do
  begin
    RESTRequest1.ExecuteAsync(nil, false, true, nil);
  	log('');
  end;
end;

end.
