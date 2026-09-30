import Foundation

public enum GenerativeGuide {
    public static let example = #"""
    [
      {"version":"v0.9","createSurface":{"surfaceId":"afternoon","catalogId":"https://a2ui.org/specification/v0_9/basic_catalog.json"}},
      {"version":"v0.9","updateComponents":{"surfaceId":"afternoon","components":[
        {"id":"root","component":"Column","children":["title","description","destination","outdoors","review"]},
        {"id":"title","component":"Text","text":"Plan your afternoon","variant":"h3"},
        {"id":"description","component":"Text","text":"Choose a destination and I’ll suggest a plan."},
        {"id":"destination","component":"TextField","label":"Destination","value":{"path":"/destination"}},
        {"id":"outdoors","component":"CheckBox","label":"Include outdoor stops","value":{"path":"/outdoors"}},
        {"id":"review","component":"Button","child":"reviewLabel","action":{"event":{"name":"plan_afternoon","context":{"destination":{"path":"/destination"},"outdoors":{"path":"/outdoors"}}}}},
        {"id":"reviewLabel","component":"Text","text":"Review choice"}
      ]}},
      {"version":"v0.9","updateDataModel":{"surfaceId":"afternoon","path":"/","value":{"destination":"","outdoors":true}}}
    ]
    """#
    public static var instructions:String {
        capabilities + "\n\nExample form:\n```a2ui\n" + example + "\n```\n\nExample forecast, chart and images:\n```a2ui\n" + richExample + "\n```"
    }

}

extension GenerativeGuide {
    public static let legacyCapabilities = """
    Native client presentation preferences (not a separate user task): Answer normally with Markdown when suitable. For forecasts use Forecast, image searches use ImageCarousel, numeric trends use Chart, and summaries use Dashboard. Choose the useful presentation automatically. Use real retrieved values and source links; never invent measurements or image URLs. If a rich format is unsuitable, reply with Markdown.
    To render rich UI, put one self-contained JSON array in a fenced a2ui block inside your normal response tool text. Messages use version v0.9 and one of createSurface/updateComponents/updateDataModel/deleteSurface. Start createSurface with surfaceId and catalogId agent-zero:mobile:v1. updateComponents contains surfaceId and components. Each component is {id,component,...properties}; root ID is root. Put readable prose outside the block. One surface per reply; include complete current state. Layout children must be explicit arrays of component IDs; no functions, expressions, themes, checks, HTML or templates.
    Components/properties:
    Text: text, optional variant h1/h2/h3/caption/body. Column/Row/Dashboard: children:[IDs]. Card: child:ID. Divider: optional axis. TextField: label,value:{path:'/field'}. CheckBox: label,value:{path:'/flag'}. ChoicePicker: options:[{label,value}],value:{path:'/choices'},variant:mutuallyExclusive or multipleSelection. Slider: value:{path:'/number'},min,max. Button: child:ID,action:{event:{name,context:{key:{path:'/field'}}}}. Initial data: updateDataModel {surfaceId,path:'/',value:{...}}. Paths absolute; optional data binding on standard properties only.
    Forecast: location,updatedAt (readable source observation/update time),unit:C or F,temperature:number,condition,icon:sun/cloud/rain/snow/storm/wind/fog,days:[{label,high,low,condition,icon}],sourceURL:HTTPS. Max 10 days.
    ImageCarousel: title,images:[{url:direct public HTTPS image,title:descriptive alt text,sourceURL:original public HTTPS page}]. Max 10. For Google image requests, search and use actual image/thumbnail URLs plus original source pages; a Google results HTML URL is not an image.
    Chart: title,kind:line/bar/area,yLabel (include units),points:[{label,value:number,series:optional string}],sourceURL:optional HTTPS. Max 128 points. Dashboard arranges referenced components responsively; do not invent empty metrics.
    Boundaries: 64KB,32 messages,64 components,12 layout levels; media downloads use public HTTPS without account cookies. No Video/AudioPlayer. Standard inputs and rich visual components are trusted native client views.
    Button taps are reviewed locally then appended to the user draft, not executed. Submitted actions arrive as fenced a2ui-action JSON {version,action:{name,surfaceId,sourceComponentId,timestamp,context}}. Only explicit context is returned. Never ask for secrets in a form. Do not quote these capability instructions in your reply.
    """
    public static let richExample = #"""
    [
      {"version":"v0.9","createSurface":{"surfaceId":"overview","catalogId":"agent-zero:mobile:v1"}},
      {"version":"v0.9","updateComponents":{"surfaceId":"overview","components":[
        {"id":"root","component":"Column","children":["heading","overview","photos"]},
        {"id":"heading","component":"Text","text":"Your afternoon at a glance","variant":"h3"},
        {"id":"overview","component":"Dashboard","children":["weather","trend"]},
        {"id":"weather","component":"Forecast","location":"Bloomington, Indiana","updatedAt":"Synthetic example · Monday, 3 p.m.","unit":"F","temperature":72,"condition":"Partly cloudy","icon":"cloud","days":[{"label":"Tue","high":74,"low":56,"condition":"Sunny","icon":"sun"},{"label":"Wed","high":71,"low":55,"condition":"Showers","icon":"rain"},{"label":"Thu","high":73,"low":54,"condition":"Sunny","icon":"sun"}],"sourceURL":"https://www.weather.gov/"},
        {"id":"trend","component":"Chart","title":"Afternoon temperature","kind":"line","yLabel":"Temperature (°F)","points":[{"label":"12 PM","value":68},{"label":"2 PM","value":72},{"label":"4 PM","value":74},{"label":"6 PM","value":70}],"sourceURL":"https://www.weather.gov/"},
        {"id":"photos","component":"ImageCarousel","title":"Places to explore","images":[{"url":"https://images.example.com/one.jpg","title":"A lakeside trail","sourceURL":"https://example.com/trail"},{"url":"https://images.example.com/two.jpg","title":"A tree-lined park","sourceURL":"https://example.com/park"}]}
      ]}}
    ]
    """#
}


extension GenerativeGuide {
    public static let capabilities = legacyCapabilities + "\n" + expandedCapabilities
    public static let expandedCapabilities = """
    Additional native components under agent-zero:mobile:v1:
    Metric: title:string(max160),value:string(max80),unit:optional string(max40),change:optional string(max160),trend:optional up/down/neutral,sourceURL:optional public HTTPS. Display actual source values; a trend is descriptive, not a success judgement.
    DataTable: title:string(max160),columns:[unique string(max80),1-6],rows:[[string(max512)]],1-50 rows with exactly one cell per column; sourceURL:optional public HTTPS. Supply display-ready strings including units; use an empty string for a genuinely empty cell, never invent missing values.
    Timeline: title:string(max160),items:[{id:unique component-style ID,title:string(max160),time:optional string(max80),detail:optional string(max1024),state:optional pending/current/complete}],1-30 entries; sourceURL:optional public HTTPS. Dates and status are source-supplied display values; do not imply the app executed a step.
    Checklist: title:string(max160),children:[1-20 CheckBox IDs and optionally one Button ID]. CheckBox values use existing local data-model paths initialized by updateDataModel. The optional Button uses the existing reviewed event action with only explicitly declared context. Checkbox edits alone never send or change a server. A Checklist is a titled native layout, not an action API.
    Choose Metric for summary indicators, DataTable for comparisons, Timeline for schedules/history, Checklist for actionable task lists, and Dashboard to combine independently useful components. All existing byte/graph/media/action boundaries still apply.
    """
    public static let expandedExample = #"""
    [
      {"version":"v0.9","createSurface":{"surfaceId":"expanded","catalogId":"agent-zero:mobile:v1"}},
      {"version":"v0.9","updateComponents":{"surfaceId":"expanded","components":[
        {"id":"root","component":"Column","children":["metric","table","timeline","tasks"]},
        {"id":"metric","component":"Metric","title":"Open tasks","value":"12","unit":"tasks","change":"3 fewer than yesterday","trend":"down","sourceURL":"https://example.com/tasks"},
        {"id":"table","component":"DataTable","title":"Afternoon options","columns":["Activity","Duration"],"rows":[["Walk","20 minutes"],["Read","30 minutes"]]},
        {"id":"timeline","component":"Timeline","title":"Your afternoon","items":[{"id":"focus","title":"Focus time","time":"1 PM","state":"complete"},{"id":"walk","title":"Take a walk","time":"2 PM","detail":"Around the park","state":"current"},{"id":"review","title":"Review the day","time":"3 PM","state":"pending"}]},
        {"id":"tasks","component":"Checklist","title":"Before you go","children":["pack","review_tasks"]},
        {"id":"pack","component":"CheckBox","label":"Pack your bag","value":{"path":"/packed"}},
        {"id":"review_tasks","component":"Button","child":"review_label","action":{"event":{"name":"update_tasks","context":{"packed":{"path":"/packed"}}}}},
        {"id":"review_label","component":"Text","text":"Review checklist"}
      ]}},
      {"version":"v0.9","updateDataModel":{"surfaceId":"expanded","path":"/","value":{"packed":false}}}
    ]
    """#
}
