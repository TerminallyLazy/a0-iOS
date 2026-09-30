import Foundation

extension GenerativeGuide {
    public static let chartMediaCapabilities = """
    Extended Chart contract supersedes the preceding Chart kind list: title,kind,yLabel (units),optional xLabel and sizeLabel,points,optional sourceURL. Kinds: line,bar,area,horizontalBar,groupedBar,stackedBar,stackedArea,pie,donut,scatter,bubble,histogram,range,heatmap. Each point has label,value:number,optional series,x:number,size:number,lower:number,upper:number,row:string. Use only observed data. Max128 points,32 categories,8 series; titles/axis/series/category labels max160 bytes. All numbers finite with absolute value <1e12. Category+series pairs unique, in intended display order. line/area support multiple series; area overlays unstacked; bar/stackedBar stack by series; groupedBar compares side by side; horizontalBar ranks categories. stackedArea uses nonnegative values. pie/donut:1-7 unique categories, strictly positive values, no series. scatter: numeric x plus required xLabel; bubble additionally positive size and optional sizeLabel explaining magnitude. histogram: source-supplied ordered nonoverlapping lower/upper bin edges, upper>lower, value>=0 count, required xLabel, no series; never fabricate or silently calculate bins. range: lower<upper, lower<=value<=upper (central observation). heatmap: label is column, row is category, value is intensity, unique column+row pairs, no series. Every chart provides a readable values disclosure. Choose the chart for the data, not decoration.
    AudioPlayer: title:string(max160),url:direct public HTTPS media,optional transcript:string(max8192),sourceURL:optional public HTTPS. Video: same properties; transcript may describe visual content or transcribe speech. Supply actual retrieved media and faithful text only. No autoplay. The user explicitly loads bounded files then uses native play/pause/seek controls. Audio accepts MP3, M4A/MP4 audio, AAC, WAV; video accepts MP4 or QuickTime with device-supported codecs. Limits32MiB audio/100MiB video. No HTML embeds, YouTube/watch pages, HLS/DASH playlists, data/file URLs, authenticated server paths, or remote subresources. Unsupported media remains a normal confirmed source link in prose; never disguise a webpage as a media file. Native media is eligible as a Jev candidate; no URLs, transcripts or measurements belong in external selection descriptions.
    """
}


extension GenerativeGuide {
    public static let directMediaGuidance = """
    When the user asks to listen to audio or view video, supply AudioPlayer or Video in the explicit a2ui surface alongside readable prose and source links. Do not stop at listing direct URLs when a supported public file is available. For delegated research, collect the actual direct URLs and source information, then compose the native media surface in the final user-facing reply; do not assume a subagent inherits these client instructions. The app can offer passive previews for ordinary public MP3/M4A/AAC/WAV/MP4/MOV links, but explicit components remain preferred for meaningful titles and transcripts. Only user Load downloads a file, and playback still requires Play. Unsupported or unverified files remain source links; never fabricate media or transcripts.
    """
    public static let mediaExample = #"""
    [
      {"version":"v0.9","createSurface":{"surfaceId":"media","catalogId":"agent-zero:mobile:v1"}},
      {"version":"v0.9","updateComponents":{"surfaceId":"media","components":[
        {"id":"root","component":"Column","children":["audio","video"]},
        {"id":"audio","component":"AudioPlayer","title":"Retrieved audio title","url":"https://media.example.com/recording.mp3","sourceURL":"https://example.com/audio-source"},
        {"id":"video","component":"Video","title":"Retrieved video title","url":"https://media.example.com/clip.mp4","sourceURL":"https://example.com/video-source"}
      ]}}
    ]
    """#
}
