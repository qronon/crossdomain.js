package
{
	import flash.display.Sprite;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLRequestHeader;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.errors.IOError;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import mx.utils.ArrayUtil;
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	import com.adobe.serialization.json.JSONEncoder;
	import com.adobe.serialization.json.JSON;
	import flash.system.Security;
	import flash.utils.setTimeout;
	
	public class crossdomain extends Sprite{
			
		public function crossdomain(){
			init();
		}
		private function init():void{
			try{
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");
				
				ExternalInterface.addCallback("request",request);
				ExternalInterface.call("crossdomain_onload");
			}catch(e:Error){
				setTimeout(init,100);
			}
		}
		
		public function request(id:String, url:String, contentType:String = null, post:String = null
				, headers:Array = null, recurseLimit:Number = -1, type:String = "json"):void{
			var urlreq:URLRequest = new URLRequest(url);
			if(post){
				urlreq.method = URLRequestMethod.POST;
				urlreq.data = post;
			}else{
				urlreq.method = URLRequestMethod.GET;
			}
			//urlreq.requestHeaders.push(new URLRequestHeader("Connection","close"));	
			if(headers){
				for(var i:String in headers){
					urlreq.requestHeaders.push(new URLRequestHeader(i,headers[i]));
				}
			}
			if(contentType){
				urlreq.contentType = contentType;
			}
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE,function(e:Event):void{
				try{
					var obj:Object = new Object;
					obj.event = e;
					if(type == "json"){
						obj.xml = convert(loader.data,recurseLimit);
					}else{
						obj.data = loader.data
					}
					sendToJS(id,obj);
					loader.close();
				}catch(e:Error){
					sendError(id,"ParseError");
				}
			});
			var reportHandler:Function = function(e:Event):void{
				sendToJS(id,{
					event:e
				});
			};
			loader.addEventListener(HTTPStatusEvent.HTTP_STATUS,reportHandler);
			loader.addEventListener(IOErrorEvent.IO_ERROR,reportHandler);
			loader.addEventListener(Event.OPEN,reportHandler);
			loader.addEventListener(ProgressEvent.PROGRESS,reportHandler);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,reportHandler);
			loader.load(urlreq);
		}
		
		private function convert(obj:*, rec:int):Object{
			if(obj is String){
				var xml:XML = new XML(obj);
				xml.normalize();
				return convert(xml,rec);
			}else if(obj is XML){
				var x:XML = XML(obj);
				if(x.hasComplexContent()){
					var o:Object = new Object();
					
					var alist:XMLList = x.attributes();
					for(var j:String in alist){
						var qname:String = alist[j].name().localName;
						o["_"+String(qname)] = String(alist[j]);
					}
					
					var xlist:XMLList = x.children();
					for(var i:String in xlist){
						var name:String = xlist[i].name().localName;
						var target:* = o[name];
						if(target){
							if(target is Array){
								if(rec > 0 && target.length > rec)
									break;
								o[name].push(convert(xlist[i],rec));
							}else{
								var a:Array = new Array;
								a.push(o[name]);
								a.push(convert(xlist[i],rec));
								o[name] = a;
							}
						}else{
							o[name] = convert(xlist[i],rec);
						}
					}
					return o;
				}else{
					//trace("value:"+x.toString());
					return x.toString();
				}
			}
			return null;
		}
		
		private function sendError(id:String, message:String):void{
			ExternalInterface.call("crossdomain_error",id,message);
		}
		
		private function sendToJS(id:String, obj:Object):void{
			ExternalInterface.call("crossdomain_call",id,obj);
		}
	}
}