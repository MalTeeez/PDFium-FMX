unit APIUnit;

interface

uses
	System.JSON, System.SysUtils, System.Diagnostics, System.Classes;


procedure sendTestRequest();
function stringFromAPI(field : string): String;


implementation

uses logUnit, FileView;

var
  stopwatch : TStopWatch;

procedure log(text : string);
begin
  LogUnit.LogForm.log(text);
end;

procedure processReqResponse(response : string);
var
  respJSONObject : TJSONObject;
begin
  respJSONObject := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(response), 0) as TJSONObject;
  stopwatch.Stop;
  FileViewForm.Label1.Text := '(' + IntToStr(stopwatch.ElapsedMilliseconds) + ') '
  + respJSONObject.GetValue<string>('value');
  stopwatch.Reset;
end;

procedure sendTestRequest();
begin
	stopwatch := TStopwatch.Create;
  stopwatch.Start;
  with FileViewForm do
  begin
    RESTRequest1.ExecuteAsync(procedure
    begin
    	processReqResponse(RESTResponse1.Content);
    end, false, false);
  end;
end;

procedure awaitString(var holder : String);
var
	tohold : string;
begin
	log('Created Await Thread');
	tohold := holder;
	TThread.CreateAnonymousThread(procedure
                                begin
                                	tohold := '';
                                 repeat
                                   sleep(1);
                                 until (tohold <> '');
                                end);
  log('Reached End of Await Thread');                              
end;

function stringFromAPI(field : string): String;
var
res : string;
begin
	stopwatch := TStopwatch.Create;
  stopwatch.Start;
  with FileViewForm do
  begin
    RESTRequest1.ExecuteAsync(procedure
    begin
    	log((TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(RESTResponse1.Content), 0).GetValue<string>(field)));
    end, false, true);
  end;
  FileViewForm.Label1.Text := '(' + IntToStr(stopwatch.ElapsedMilliseconds) + ')';
  stopwatch.Reset;
end;

end.
