import sys,re,time,urllib,json,base64,YDMHttp,zlib,threading

######################################################################

class SNWorker(threading.Thread):
    wname = '' #进程名称
    currentSN = ''
    picPath = 'testFolder/'

    mainURL = 'https://checkcoverage.apple.com/us/en/'
    cookieValue = ''
    csrfToken = ''
    jsession = ''
    dpsq = ''
    binaryValue = ''

    username = "{$1}";
    password = "{$2}";
    appid = "{$3}";
    appkey = "{$4}";
    codetype = 1005;
    timeout = 60;
    lastDamaPicID = 0;
    serverIsError = 0;

    yundama = "";
    uid = "";

    def __init__(self, threadID, name, sn):
        threading.Thread.__init__(self)
        self.threadID = threadID;
        self.name = name;
        self.currentSN = sn;
        self.yundama = YDMHttp.YDMHttp(self.username, self.password, self.appid, self.appkey)
        self.uid =  self.yundama.login();

    def run(self):
        print("Starting Thread:" + self.wname)
        self.openMainPage();

    # 打开首页
    def openMainPage(self):
        try:
            self.serverIsError = 0;
            request = urllib.request.Request(self.mainURL)
            response = urllib.request.urlopen(request)
            responseHTML = response.read().decode('utf-8')
            # 从结果内容中查找是否有特定字符串
            self.cookieValue = response.getheader('Set-Cookie');
            # print("YO:"+self.cookieValue)
            if (self.cookieValue.find('JSESSIONID') >= 0):
                matchObj = re.search(r'JSESSIONID=([^;]*)', self.cookieValue, re.M | re.I)
                self.jsession = matchObj.group(1);
            if (self.cookieValue.find('NSC_MCWT_difdldpwfsbhf') >= 0):
                matchObj = re.search(r'NSC_MCWT_difdldpwfsbhf-bt\.dpsq_443=([^;]*)', self.cookieValue, re.M | re.I)
                self.dpsq = matchObj.group(1);
            # find csrfToken
            if (responseHTML.find('csrfToken') >= 0):
                matchObj = re.search(r'csrfToken:\s\"([^\"]*)', responseHTML, re.M | re.I)
                self.csrfToken = matchObj.group(1);
        except Exception as e:
            self.serverIsError = 1;
            print('oops!Please check network!')
            print(e)
            self.markSNResult(3);
        if (self.serverIsError == 0):
            self.validateParms();

    # 验证得到的参数是不是完整的
    def validateParms(self):
        # print("3 Prams:",self.jsession,self.dpsq,self.csrfToken)
        if (self.csrfToken != '' and self.jsession != '' and self.dpsq != ''):
            print("Parameter is complete")
            self.getCode()
        else:
            print("Parameter lost")
            self.markSNResult(3);

    # 获取验证码
    def getCode(self):
        print("get verification code...")
        # 时间戳
        timeStamp = int(time.time())
        myURL = "https://checkcoverage.apple.com/gc?t=image&timestamp=" + str(timeStamp) + "000"
        try:
            self.serverIsError = 0;
            request = urllib.request.Request(myURL)
            request.add_header('pragma', 'no-cache')
            request.add_header('Host', 'checkcoverage.apple.com')
            request.add_header('Referer', 'https://checkcoverage.apple.com/cn/zh/')
            request.add_header('X-Requested-With', 'With:XMLHttpRequest')
            newCookie = "JSESSIONID=#1; s_vnum_n2_cn=4%7C1; s_pathLength=support%3D2%2C; s_cc=true; s_fid=60F4365C9CDC7666-3769300719D83810; s_sq=applecnglobal%2Capplecnsupport%3D%2526pid%253Dacs%25253A%25253Atools%25253A%25253Awck%25253A%25253Acheck%25253A%25253Azh_cn%2526pidt%253D1%2526oid%253Dfunctiononclick%252528event%252529%25257Bvoid%2525280%252529%25257D%2526oidt%253D2%2526ot%253DDIV; POD=cn~zh; NSC_MCWT_difdldpwfsbhf-bt.dpsq_443=#2; s_vi=[CS]v1|2D16FA8E852E347C-60000C30A0003D31[CE]"
            newCookie = newCookie.replace("#1", self.jsession);
            newCookie = newCookie.replace("#2", self.dpsq);
            # print(newCookie)
            request.add_header('Cookie', newCookie)
            response = urllib.request.urlopen(request)
            html = response.read().decode('utf-8')
            jsonObj = json.loads(html)
            imgBytes = base64.b64decode(jsonObj["binaryValue"])
            file_object = open(self.picPath+'code_'+str(self.threadID)+'.jpg', 'wb')
            file_object.write(imgBytes)
            file_object.close()
            # 打码
            cid, result = self.yundama.decode(self.picPath+'code_'+str(self.threadID)+'.jpg', self.codetype, self.timeout);
            self.lastDamaPicID = cid;
            print('cid: %s, result: %s' % (cid, result))
        except Exception as e:
            self.serverIsError = 1;
            print('oops code!Please check network!')
            print(e)
            self.markSNResult(3);
        if (self.serverIsError == 0):
            # 验证SN
            self.doValidate(result);

    # 验证SN是否为真
    def doValidate(self,yzCode):
        print("Validate SN:" + self.currentSN)
        myURL = "https://checkcoverage.apple.com/us/en/?sn=" + self.currentSN;
        newCookie = "JSESSIONID=#1; s_cc=true; s_pathLength=support%3D1%2C; s_invisit_n2_cn=4; s_vnum_n2_cn=4%7C1; POD=cn~zh; NSC_MCWT_difdldpwfsbhf-bt.dpsq_443=#2; s_vi=[CS]v1|2D174EE0852E4236-40000D2EA000D314[CE]; s_fid=646B1C7FA50790CD-1653AEDAE0709D92; s_sq=applecnglobal%2Capplecnsupport%3D%2526pid%253Dacs%25253A%25253Atools%25253A%25253Awck%25253A%25253Acheck%25253A%25253Azh_cn%2526pidt%253D1%2526oid%253D%2525E7%2525BB%2525A7%2525E7%2525BB%2525AD%25250A%2526oidt%253D3%2526ot%253DSUBMIT";
        newCookie = newCookie.replace("#1", self.jsession);
        newCookie = newCookie.replace("#2", self.dpsq);
        data = {'sno': self.currentSN, 'ans': yzCode, 'captchaMode': 'image', 'CSRFToken': self.csrfToken}
        body_value = urllib.parse.urlencode(data).encode(encoding='UTF8')
        try:
            request = urllib.request.Request(myURL, body_value)
            request.add_header('Host', 'checkcoverage.apple.com')
            request.add_header('Referer', myURL)
            request.add_header('Content-Type', 'application/x-www-form-urlencoded')
            request.add_header('Cookie', newCookie)
            request.add_header('Origin', 'https://checkcoverage.apple.com')
            request.add_header('Upgrade-Insecure-Requests', '1')
            request.add_header('User-Agent',
                               'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) Chrome/62.0.3202.94 Safari/537.36')
            # request.add_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8')
            request.add_header('Accept-Encoding', '')
            request.add_header('Accept-Language', 'en-US;q=0.9,en;')
            response = urllib.request.urlopen(request)
            html = response.read().decode('utf-8', 'ignore')
            # print(html)
            if (html.find('errorType: "",') >= 0):
                print("Verification passed, information is valid")
                self.markSNResult(1)
            else:
                matchObj = re.search(r'errorType\:\s\"([^\"]*)\",', html, re.M | re.I)
                errorType = matchObj.group(1);
                print(errorType)
        except urllib.error.HTTPError as e:
            print('oops validate!Please check network!')
            print(e)
            if hasattr(e, 'code'):
                print('Error code:', e.code)
            if (e.code == 500):
                html = zlib.decompress(e.read(), 16 + zlib.MAX_WBITS).decode("utf-8");
                # 匹配错误类型
                matchObj = re.search(r'errorType\:\s\"([^\"]*)\"', html, re.M | re.I)
                errorType = matchObj.group(1);
                if (errorType == "captchaError"):
                    print("Verification code error")
                    self.markSNResult(4);
                    self.yundama.report(self.lastDamaPicID)
                elif (errorType == "snError"):
                    print("The serial number is illegal")
                    self.markSNResult(2);
                else:
                    print("Other mistakes")
                    self.markSNResult(3);
            else:
                self.markSNResult(3);

    # 标记验证结果:1=信息为真，2=信息为假，3=需要更换IP，4=验证码错了
    def markSNResult(self,tag):
        print("SNRET:" + str(tag) + ":" + self.currentSN)
