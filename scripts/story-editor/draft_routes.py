"""Build the approved route framework from the preserved chapter draft.

Writes a separate candidate JSON; applying it to the live editor is an explicit API save.
This is an authoring draft, not a runtime story compiler or a balancing configuration.
"""
import copy
import json
from pathlib import Path
from store import validate

WORKSPACE = Path(__file__).resolve().parents[2]
SOURCE = WORKSPACE / 'docs/文案/主线/主线故事图_章节稿_v01.json'
TARGET = WORKSPACE / '.tmp/story-routes-candidate.json'


def build():
    old = json.loads(SOURCE.read_text(encoding='utf-8'))
    source = {n['id']: n for n in old['nodes']}
    p = {'format': 'human-world-story', 'version': 1, 'layout': 'route',
         'title': '寄往人间 · 主线路线梗概 v02', 'nodes': [], 'edges': [],
         'notes': '按主线轮次纵向推进，普通愿望隔日插入。18轮/36天是可修改讨论排期；未接入游戏。'
                  '先定流程，再写正文。四种案件结果与五种身份结果分开。箭头条件是作者说明，不是可执行规则。'
                  '暂沿用选瓶子→熬药→后续，不新增人物直接接受玩家指令的菜单。',
         'templates': []}
    structures = {
        'opening': ('开端与认识人物', '陌生处境→眼前的小愿望→来信透露一个人的过去→下一条线索。只写人物实际知道的事。'),
        'witness': ('证人的下一步', '前情：安全／躲藏／含糊／被压住。列清谁能联系谁、已有哪份纸。两封念头提出不同下一步；结果分别记录联系、递交、保护与伤害。'),
        'land': ('土地旧债', '旧图与原约→逐户核对→当事人的立场→两封念头→公示、交接或停滞。返还不是施舍，收款不代表原谅。'),
        'clinic': ('诊疗所核对', '实际转款凭据、代号与病人处境→说明资料或保护人→可核对程度与身份风险。财务违规与谋杀分开。'),
        'archive': ('封存与经手说明', '已有材料及缺口→两人各自面对封存→原登记／具名说明／缺口→留给人间问询。纸与记忆分别记录。'),
        'harbor': ('末班船与实际执行', '材料完整度、证人、安全安排、离开计划→复核或交接→实际问询／实际控制／实际离开→四种案件结果。不得从药效或星级直接跳判真凶归案。'),
        'restitution': ('返还执行', '逐户确认及公示名目→更正名目或办理支付→本人回执→未处理家庭继续存在。不得凭道歉生成到账。'),
        'relief': ('救助到货', '本期已知来源、运输与分配→冬衣或煤药→实际签收及缺口。未选去向不免费收到同一车货。'),
        'identity': ('结局与身份', '已保存案件、土地与救助后续→经营收尾→按既有资格揭晓唯一身份。旅人是有效窗口内主动离场。'),
    }
    for tid, (title, summary) in structures.items():
        p['templates'].append({'id': tid, 'title': title, 'summary': summary})

    def node(nid, round_, title, summary, kind='choice', step=0, template='opening',
             context='', options='', conditions='', effects='', notes=''):
        n = {'id': nid, 'parentId': None if nid == 'root' else 'root', 'kind': kind,
             'title': title, 'summary': summary, 'round': round_, 'step': step,
             'templateId': template, 'context': context, 'options': options,
             'conditions': conditions, 'effects': effects, 'notes': notes,
             'status': '讨论草案', 'dx': 0, 'dy': 0, 'collapsed': False}
        if kind in ('main', 'choice') and 1 <= round_ <= 18:
            n['day'] = round_ * 2
        p['nodes'].append(n)
        return nid

    def edge(a, b, label='继续', condition=''):
        p['edges'].append({'id': 'route_' + str(len(p['edges']) + 1), 'from': a, 'to': b,
                           'label': label, 'condition': condition, 'kind': 'next'})

    def results(scene, round_, rows, template):
        ids = []
        for index, (label, synopsis, facts) in enumerate(rows, 1):
            nid = scene + '_r' + str(index)
            node(nid, round_, label, synopsis, 'result', 1, template,
                 context='承接本场前情；之前已发生的事实不会被本结果清空。',
                 conditions=label + '；药效数值及触发优先级待后续正文、数值阶段制定。',
                 effects=facts, notes='星级按许愿者满意度另定；不是道德或破案评分。')
            edge(scene, nid, label)
            ids.append(nid)
        return ids

    def original_results(scene, original, round_, template, extra=''):
        rows = []
        for letter in ('a', 'b'):
            actor = source[original + '_' + letter]['title'].split(' · ', 1)[-1]
            for i in range(1, 4):
                n = source[f'{original}_{letter}_r{i}']
                rows.append((f'{letter.upper()}{i} · {n["title"][:25]}', n['summary'] + extra,
                             actor + '：' + n['effects'] + '。其余事实读取此前实际结果。'))
        return results(scene, round_, rows, template)

    def pair_options(original):
        return '\n'.join(source[f'{original}_{letter}']['title'] for letter in ('a', 'b'))

    node('root', 0, '海边醒来，先替一个人完成小愿望',
         '失去身份记忆的人接手魔药铺。海里捞出的文字来自人间的念头，人们并不知道店铺存在。第一个普通愿望让玩家认识剪词、熬药与回信。',
         'root', context='玩家不知道自己是谁。', options='第1天普通愿望；第2天开始主线。',
         effects='只保留经营与真实订单记录，不生成隐藏道德分。')
    for index in (1, 6, 7, 8):
        original = source[f'm{index:02}']
        node(original['id'], index, original['title'], original['summary'], 'main',
             context='穿插在普通愿望后的主线来信。各人只能说明自己知道、见过或拿到的东西。',
             options={1:'缝补员的来信：孩子们的冬衣与捐衣场外的旧地契。',6:'神父的稿纸：承认土地责任、重新检查账目与投诉。',7:'抄写员的记录：同一编号上的两处住址。',8:'配送员的收条：当日下午递送及后来换签要求。'}[index],
             effects=original['effects'], notes=original['notes'])
    edge('root', 'm01', '隔一天收到冬衣的念头')
    node('m02', 2, 'M02 空椅子与藏起的赔偿文件',
         source['m02']['summary'], 'main', template='land', context='父亲遇害，玛拉既愤怒又不愿失去家人的记忆。老石匠的旧图指向另一种父亲形象。',
         options='玛拉的瓶子：想坐下来理清父女争吵和文件。', effects='藏文件的行为、旧图与可取得原件分别记录。')
    edge('m01', 'm02', '冬衣背后的捐助者已经死了')
    m2 = results('m02', 2, [
        ('承认取走文件，开始整理', '玛拉说明自己拿走赔偿文件的原因，愿意把旧图与父亲留下的原件并放核对。', '开始核对，不等于已经完成返还；原件取得另记。'),
        ('急于替父亲辩解，谈话破裂', '她把对石匠的愤怒一并说出，亲人停止追问。旧图仍在，但她暂时拒绝同石匠见面。', '会面关系恶化，纸面材料仍在。'),
        ('争吵说不清，原件尚未清点', '她记不清自己同父亲争论的部分，迟迟没有打开文件柜。旧图副本不能当成完整原约。', '指定争吵记忆缺口或行动拖延；不自动抹去纸件。')], 'land')
    finance = [
        ('m03', 'M03 假账：她愿意说明钱的去处', '玛拉开始清点文件，阿德琳担心转款记录也被误读。她知道自己改过账，但钱送去了旧港诊疗所。'),
        ('m03_dispute', 'M03 假账：别把她也当成窃贼', '宅邸争论不断，阿德琳怕一句话就坐实私吞。她想讲清账外钱，却不肯把病人名单交给围观者。'),
        ('m03_wait', 'M03 假账：先保住手边的凭据', '原柜尚未理完，阿德琳只能从自己保存的转款单开始说明。缺少的原件不能由一句解释补出来。')]
    m3_groups = []
    for (nid, title, synopsis), previous in zip(finance, m2):
        node(nid, 3, title, synopsis, 'main', template='clinic', options='阿德琳的瓶子：说出账外转款，又不牵连病人。', context=source['m03']['summary'])
        edge(previous, nid, '阿德琳面对不同的追问背景')
        m3_groups.append(results(nid, 3, [
            ('说明转款，匿名对应单独保管', '她拿实际转款凭据说明去向，代号与真实姓名分开，不把诊疗所违规直接当成谋杀。', '财务说明已做；匿名对应受限保管。'),
            ('一口气说得太多，病人身份流出', '她急于让人相信自己，连不该公开的名字也说了出来。医生必须先应付病人的恐惧。', '身份暴露风险实际发生；钱款凭据仍需核对。'),
            ('代号说不清，核对暂时停下', '她记不起自己保管的代号对应，或没能及时开口。转款单仍在，口述不作为确定对应。', '未核对代号；指定记忆缺口不得因下一单忘记值降低而恢复。')], 'clinic'))
    clinic_early = [
        ('m04', 'M04 匿名病人：怎样回答又不伤人', '有限的财务说明使调查转向诊疗所。伊莱拉需要区分治疗记录、病人身份与药酒检验。'),
        ('m04_exposed', 'M04 匿名病人：先安顿害怕的人', '有人听见了真实姓名，病人准备搬走。伊莱拉想留住他们，也要处理调查已经提出的问题。'),
        ('m04_limited', 'M04 匿名病人：只回答能核对的部分', '账房没讲清代号，伊莱拉只能逐项说明自己确定的治疗经过，不能替账房补出不存在的记忆。')]
    m4_groups = []
    for i, (nid, title, synopsis) in enumerate(clinic_early):
        node(nid, 4, title, synopsis, 'main', template='clinic', options='伊莱拉的瓶子：回答调查，同时保护病人。', effects='药酒检验摘要作为独立纸件抵达；不随医生星级或私人记忆消失。')
        for group in m3_groups:
            edge(group[i], nid, '医生面对不同的病人处境')
        m4_groups.append(results(nid, 4, [
            ('说明治疗经过，守住匿名边界', '她把能确认的医疗经过与检验摘要分开说明，只向有权限的人提供必要对应。', '医疗经过可用；检验纸件留存；不自动取得原登记。'),
            ('把名字说给了不该取得的人', '她越说越急，名单传播到了诊疗所外。有人离开住处，后面的核对需要重新联络。', '身份风险与联络困难保留，检验纸件仍在。'),
            ('私人转诊经过含糊，问询停滞', '她无法清楚说明自己经手的转诊经过，或迟迟没有参与问询。纸上的检验结果没有因此消失。', '口述或行动缺口保留；不把有检验纸等同责任已核实。')], 'clinic'))
    node('m05', 5, 'M05 一百箱与七十六箱', source['m05']['summary'], 'main',
         context='诊疗所与孤儿院都在等待物资，运输账的差额成为另一个问题。',
         options='吕西安的瓶子：面对仓库核查。', effects='运输案偏向与证据独立保存，不等于谋杀证明。')
    for group in m4_groups:
        for r in group:
            edge(r, 'm05', '下一封念头来到运输账上', '带着本支病人处境继续；不会重置')
    m5 = results('m05', 5, [
        ('面对差额，但仍有隐瞒', '吕西安能回答核查，却避开死亡当晚派人寻找记录的动机。独立运输纸件继续留下。', '运输案线索形成；他不是调换药酒的真凶。'),
        ('威胁工人别再多嘴', '他把镇定用在压住工人上，仓库里出现有人愿意记下威胁、却不愿替他作证的局面。', '威胁旁证不是药酒经手证词。'),
        ('调货记忆模糊，原账仍在', '他说不清自己调走哪批货，核查只能继续查原始运输单。', '指定调货记忆缺口；不能抹去他人的见闻或纸件。')], 'witness')
    for r in m5:
        edge(r, 'm06', '神父留下未宣读的稿纸')
    edge('m06', 'm07', '稿纸提到要让未送达的声音真正抵达')
    edge('m07', 'm08', '旧地址问题之外，追查当日配送')
    node('p01', 9, '仓库门口：谁先把话说出来', '托马斯带着仓库见闻准备开口，吕西安想掌握核查顺序。门口只有一次安全接待机会，帮助谁、药效怎样，会改变少年下一步能去哪里。',
         template='witness', context='已有药酒检验、V17配送材料、改革稿纸及旧K42副本；托马斯只知道箱子、号码和听见的话，并未看到调换。',
         options=pair_options('p01'), notes='这里开始高频两封瓶子二选一。未选的一封不免费实现。')
    edge('m08', 'p01', '两封瓶子同时出现')
    p1 = original_results('p01', 'p01', 9, 'witness')
    witness_specs = [
        ('witness_safe', '证词送达后：留下补问，还是先安顿', '托马斯已经安全递交证词，但不能无限期待在警备所。他想同伙伴离开；罗文想把补问与实际保护安排妥当。',
         'A · 托马斯：同伙伴离开，留下能联系的住址。\nB · 罗文：完成补问，并安排实际保护。',
         [('A1 · 地址留准，安全离开', '他同伙伴离开，留下可核对的住址与联络人。既有证词不因离开失效。', 'safeStatement=true；reachable=true。'),
          ('A2 · 走得急，住址没留全', '他急着摆脱警备所，伙伴也不知道以后怎样联系。旧证词仍在，补问失去对象。', 'safeStatement保留；reachable=false。'),
          ('A3 · 联络说明含糊', '他记不起指定联络对象，留下一条无法确认的地址。不能假装下一轮自动联系得上。', '旧证词保留；联络未核实。'),
          ('B1 · 补问完成，保护落实', '罗文逐项问清少年真正见闻，安排同伴和留宿地点；问询记录留下来源。', '安全补问与实际保护都已发生。'),
          ('B2 · 忙于追问，保护没有交接', '罗文问了许久，却没有把安顿工作交给具体的人。少年从走廊自行离开，原记录保留。', '补问记录按实际内容；保护未落实。'),
          ('B3 · 只记下支持既有猜测的话', '罗文忘了指定的核对要点，遗漏少年说过的先后。原证词不能因此被改写。', '补问不完整；原证词仍可供后续核对。')]),
        ('witness_hidden', '少年躲开后：保持联系，还是留下旁证', '少年在临时住处躲着，朋友也受到惊吓。眼下首先是能否找到人，而不是立刻得到完整证词。',
         'A · 托马斯：敢把自己的落脚处告诉可信的人。\nB · 仓库工友：写下门口威胁的经过。',
         [('A1 · 给可信的人留下去向', '他只向能安顿自己的同伴说明位置，随后收到正式问询安排。', '人可联系；正式安全证词仍需实际问询，不能此处免费生成。'),
          ('A2 · 再去当面对质', '他误把开口当成一定要当面讨说法，再度暴露了自己的落脚处。', '联络与安全风险升高；未得到安全证词。'),
          ('A3 · 连落脚处也说不准', '他写不清指定联络信息，朋友只能继续找人。', '联络未核实，旧纸仍在。'),
          ('B1 · 工友签下威胁经过', '工友只记录自己看见的驱赶和威胁，愿意在警备所核实。', '威胁旁证；不替代少年安全证词，不证明调换。'),
          ('B2 · 指控里混进没见过的事', '工友越说越激动，把传闻也当成亲见。罗文必须分开记录。', '仅亲见部分可核对；传闻不能升级为证据。'),
          ('B3 · 没能递交记录', '他把纸藏起来或拖延出门，愿意作证仍不等于已经送达。', '旁证未递交；少年处境保留。')]),
        ('witness_blurred', '号码说不清后：查收条，还是限定口述', '纸面号码仍在，但人的私人记忆出了缺口。后续转向可独立核对的记录。',
         'A · 配送员乔纳：把V17收条的来源讲清楚。\nB · 托马斯：只写自己仍能确定的见闻。',
         [('A1 · 收条经手顺序说明清楚', '乔纳复核自己递送药酒的时间与签收，不把配送等同调换。', 'V17来源复核；少年证词没有因此补齐。'),
          ('A2 · 把猜测也写进收条说明', '他想帮忙，写下了自己没有见过的宅邸内动作。', '实际配送可核对，宅邸猜测删除或标注未证实。'),
          ('A3 · 私人口述含糊，收条不消失', '乔纳无法解释指定经手细节，原收条仍封存。', 'V17纸件保留；口述缺口独立。'),
          ('B1 · 明确写下确定与不确定', '托马斯没有补造记忆，把能确定的箱子和听闻分开写出。', '有限口述；永久淡化的对象不恢复。'),
          ('B2 · 为证明自己硬拼先后', '他把推测排成顺序，问询时与实际纸件冲突。', '口述仍不可靠，不生成安全完整证词。'),
          ('B3 · 写了一半，没有送出', '他停在不确定的号码上，把纸收回去。', '有限草稿未递交。')]),
        ('witness_silenced', '门被关上后：先留现场，还是再递那张纸', '吕西安压住仓库入口，托马斯的纸尚未进入正式记录。镇住场面让商人满意，却使调查失去一个人。',
         'A · 仓库工友：保留核查门口的现场记录。\nB · 托马斯：去安全地点递交藏着的纸。',
         [('A1 · 现场记录送到警备所', '工友逐项写下关门、驱赶及实际在场者，运输核查有了独立记录。', '仓库旁证送达；不替代托马斯证词。'),
          ('A2 · 在仓库吵起来', '他当面争执，记录没有交出去。', '仓库冲突；旁证未正式送达。'),
          ('A3 · 有记录却找不到递交人', '他拖延或说不清应交给谁，纸仍留在自己手里。', '现场纸件保存，尚未取得。'),
          ('B1 · 在安全接待中正式递交', '托马斯离开仓库，到能保护他的问询地点递交原纸，罗文逐项记录实际见闻。', '新增补救路线：安全证词实际生成；需后续正文与问询契约同步，未接入游戏。'),
          ('B2 · 把纸拿去质问商人', '他没有进入安全问询，而是再次要求商人认账。', '原纸未进入正式问询；暴露风险保留。'),
          ('B3 · 纸送达，指定记忆仍缺', '纸终于递交，但他讲不清号码先后。材料与有限口述分开登记。', '纸已送达，不生成完整安全证词；记忆缺口不恢复。')])]
    witness_results = []
    mapping = {0: 0, 1: 1, 2: 2, 3: 3, 4: 1, 5: 2}
    for i, (nid, title, synopsis, options, rows) in enumerate(witness_specs):
        node(nid, 10, title, synopsis, template='witness', options=options, context='由仓库门口的实际结果决定本场；保留原来的材料和人物处境。')
        for j, target in mapping.items():
            if target == i:
                edge(p1[j], nid, '进入对应的证人后续')
        witness_results.extend(results(nid, 10, rows, 'witness'))
    node('p02', 11, '土地会面：把名字念完，还是坐着听完', '玛拉已经取得能核对的旧图与原约，邀请老石匠带名单来。他怕一见她只会骂父亲，她怕听见葬礼上的话又把人赶走。谈不谈得下去，决定后面是核对、公示争议还是继续保存原件。',
         template='land', context='旧图与原约能核对，玛拉与石匠都愿意到场。谁把话说清与谁得到原谅是两件事。', options=pair_options('p02'),
         conditions='原约与住户来源已取得，双方可会面。埃德蒙成年签字并获利的事实保留。')
    node('land_wait', 11, '会面尚未成行：先补原约，还是清点文件',
         '旧图只有一份副本，或其中一人还不肯见面。先处理能证明什么、谁还能继续谈，不凭画面跳出成功会面。', template='land',
         options='A · 抄写员：把柜里保存的原约找出来核对。\nB · 玛拉：打开父亲留下的文件柜，列清能交出的资料。',
         conditions='原约不足或双方尚不可会面。', effects='只写实际取得材料；拒绝会面不使抢地事实作废。')
    for r in witness_results:
        edge(r, 'p02', '另一条旧债线来到眼前', '材料与双方到场条件齐备；证人处境照旧')
        edge(r, 'land_wait', '土地会面先补缺口', '上述条件未齐备；不凭空获得原约')
    land_results = original_results('p02', 'p02', 11, 'land')
    waiting_results = results('land_wait', 11, [
        ('A1 · 原约核对完成', '抄写员找出原约，说明年月、印章与土地接收签字。逐户名单仍要本人核对。', '原约来源确认；不能替住户同意赔偿。'),
        ('A2 · 把旧图当成完整原约', '他急于证明指控，忽略了图与契约用途不同。', '原约缺口仍在；公开说明需修正。'),
        ('A3 · 尚未找到对应原约', '他只拿到目录，没有拿到原纸。', '原件未取得。'),
        ('B1 · 文件清单列成，发出邀请', '玛拉把现存资料逐件列清，也承认父亲参与接收土地，邀请当事人继续核对。', '清单与邀请实际发生；尚未会面，不生成到账。'),
        ('B2 · 只挑能替父亲说话的纸', '她把赔偿材料再次留在柜里，列出的清单不能说明全部责任。', '清单不全；土地争议保留。'),
        ('B3 · 清点停在半途', '她迟迟没能打开关键柜格，邀请未发出。', '原件与会面继续待办。')], 'land')
    public_specs = [
        ('land_public', '名字核对后：公示原委，还是请各户确认', '会面没有让所有人和解，但已经能把接收土地的责任与住户名字逐项摆出来。', '名单和责任来源已核对。'),
        ('land_dispute', '“恩典”的争议：先改名目，还是再听一遍', '有人把归还旧债说成维尔家的仁慈，或争吵盖过了名单。当事人要求把话写正，不要求他们先感谢。', '名目、责任或会面表达出现争议。'),
        ('land_pending', '会面中断后：保住原件，还是继续邀请', '材料或到场条件仍有缺口。后续先保存来源与联系人，不宣布所有家庭已得到补偿。', '尚未完成可用名单或会面。')]
    public_results = []
    for i, (nid, title, synopsis, condition) in enumerate(public_specs):
        node(nid, 12, title, synopsis, template='land', conditions=condition,
             options=('A · 抄写员：按原件更正公示和登记。\nB · 玛拉：请实际受影响家庭逐户核对、确认下一步。' if i < 2 else
                      'A · 抄写员：保管并补齐原件来源。\nB · 玛拉：重新邀请尚未能到场的人。'))
        for j, r in enumerate(land_results):
            if j % 3 == i:
                edge(r, nid, '会面后进入不同处理')
        for j, r in enumerate(waiting_results):
            # Finding an original or sending an invitation is not a completed meeting.
            target = 1 if j in (1, 4) else 2
            if target == i:
                edge(r, nid, '清点后进入不同处理', '资料仍不足时转入保留原件版本，不宣称完成逐户核对')
        public_results.extend(results(nid, 12, [
            ('A1 · 只把已核对事实写进登记', '抄写员保住原件来源，已核实的部分在公示中明确写成旧债；资料不足的家庭单列待核对。', 'publicCorrected按实际范围；不产生返还到账。'),
            ('A2 · 写了感谢，没写责任', '他想平息争论，把公示写成施舍，受损家庭拒绝在这份名目下签字。', 'labelDisputed=true；登记未获得住户认可。'),
            ('A3 · 来源记录未整理完', '他留下了纸，却没有完成可公开的来源说明。', 'publicationPending=true；原件保存。'),
            ('B1 · 一户一户确认，不强求原谅', '玛拉认真听取有来源的家庭意见，列清确认、拒绝与待联系的家庭；尚缺资料的不抢先付款。', 'householdConfirmed范围单独保存；无资料时只产生邀请与联络，不能越过原约。'),
            ('B2 · 急着拿到所有人的答应', '她催着人签名，几户中途离席。父亲的责任没有减轻。', 'householdAgreementPartial=true；不同家庭独立选择。'),
            ('B3 · 邀请或确认没有办完', '她只完成一部分联络，公示与支付尚无完整依据。', 'householdPending=true。')], 'land'))
    clinic_specs = [
        ('p03', '诊疗所核对：在匿名边界内说清账', '病人尚能联系，财务单据有实际来源。伊莱拉想守住退路，阿德琳想讲清每笔转款。', '此前未暴露病人且基本凭据可用。'),
        ('p03_exposed', '诊疗所核对：先保护已暴露的人', '有人搬离旧住处，问账的人找不到原先的名单对应。保护与说明不能用一句“都有了”同时完成。', '此前已发生身份暴露或迁移。'),
        ('p03_limited', '诊疗所核对：缺的部分不能靠猜', '代号口述不可靠，或关键凭据尚未抵达。只能核对实际有来源的记录，再明确留下缺口。', '无暴露但材料或指定记忆仍缺。')]
    clinic_results = []
    for nid, title, synopsis, condition in clinic_specs:
        node(nid, 13, title, synopsis, template='clinic', context='病人处境读取第3、4轮的实际结果，不由土地会面的结果重置。', options=pair_options('p03'), conditions=condition)
        for r in public_results:
            edge(r, nid, '带着已有病人处境继续', condition)
        clinic_results.extend(original_results(nid, 'p03', 13, 'clinic', ' 已迁移者需要实际联络；缺的原件与永久淡化记忆不免费恢复。'))
    archive_specs = [
        ('p04', '封存前：可核对的原件，或经手人的说明', '匿名对应与账已经能核对。阿德琳担心原件被带走，克莱拉想把积压信件整理得不惹出更多问题。', '资料可核对且匿名边界受保护。'),
        ('p04_exposed', '封存前：哪些纸能交，哪些名字要另封', '资料能说明一部分转款，但身份已经暴露。交出原件并不消除先前的伤害，名单权限仍需安排。', '资料可核对但病人身份已暴露。'),
        ('p04_limited', '封存前：别让含糊目录替代原登记', '仍有未送达或无法核对的纸，目录不能自动变成原账。克莱拉自己的Q17/V17说明可能留下另一条核对路径。', '资料尚不能完成原登记核对。')]
    archive_results = []
    for nid, title, synopsis, condition in archive_specs:
        node(nid, 14, title, synopsis, template='archive', context='Q17/V17是当日经手链，K42是旧物资举报，两者分别解释。', options=pair_options('p04'), conditions=condition)
        for r in clinic_results:
            edge(r, nid, '依实际核对进度进入封存', condition)
        rr = original_results(nid, 'p04', 14, 'archive', ' 原件须实际取得并核对；原登记缺失时，具名说明只作既有契约允许的替代。')
        archive_results.extend(rr)
    harbor_specs = [
        ('p06', '最后一班船：材料齐了，谁去把事办完', '已有完整问询输入，但这只是开始。罗文需要真正召集问询并控制人，玛拉也想完成宅邸交接后离开。', '检验+V17+改革稿+K42副本+安全证词+(原登记或克莱拉具名说明)，且所需来源均可核对。'),
        ('p06_gap', '最后一班船：证据有缺口，仍要守住出口', '材料没齐，罗文不能把别人的违规拼成谋杀；可以保住出口继续核对，也可能被已有运输嫌疑带偏。', '问询输入未齐，且克莱拉没有已确认离开计划。'),
        ('p06_leave', '最后一班船：有人已经备好了旅行箱', '克莱拉已有离开计划，材料仍有缺口。玛拉正常交接能满足自己的愿望，官定替班却晚于船期。', '问询输入未齐，克莱拉的离开计划已经实际形成。')]
    harbor_results = []
    for nid, title, synopsis, condition in harbor_specs:
        node(nid, 15, title, synopsis, template='harbor', conditions=condition, options=pair_options('p06'),
             context='官定旧班16:50撤、新班17:30到；玛拉正常17:00离开；克莱拉8分钟到港；17:15停登、17:20离岸。具体游戏日随新排期重定。',
             notes='不替未选罗文免费补问、安排封控；管事收到文件不等于警备接班。')
        for r in archive_results:
            edge(r, nid, '最后期限前读取实际材料与计划', condition)
        rows = [
            ('A1 · 复核与实际控制', '罗文保住出口，按实际输入召集问询。有完整输入才核实克莱拉经手调换并当场控制；材料不足时留下缺口。', '完整输入+问询完成+实际控制→归案；否则有效守港但未解。'),
            ('A2 · 先守港，不强行定罪', '他实际安排出口值守，把不足材料继续核对，不因吕西安的运输罪而宣布谋杀已破。', 'portHold=true；没有实际责任核实与控制，不归案。'),
            ('A3 · 忘了关键核对，草率下令', '他顺着已有嫌疑想尽快结案。只有已有吕西安偏向且无可靠反证，才会形成错误谋杀拘捕。', 'wrongArrest须实际下令和条件；未满足则未解。'),
            ('A4 · 迟迟没有把人召来', '材料在案头，罗文却没有完成问询与部署。未选玛拉不免费发生她的离开。', '问询与执行未发生；默认案件未解。'),
            ('B1 · 正常交接，按时离开', '玛拉把钥匙与文件交给管事，17:00离开。若克莱拉已计划离港且无实际控制，利用替班空档登船。', 'maraDeparted=true；handover=true；文件交接不等于portHold。'),
            ('B2 · 急着走，交接没有讲清', '她离开得匆忙，口述或文件交接有缺口。克莱拉能否离港仍取决于计划、窗口和实际控制。', 'maraDeparted=true；handoverIncomplete；不自动判逃脱。'),
            ('B3 · 没能离开宅邸', '她仍留在宅邸处理未完事，克莱拉不能利用本版需要玛拉离开的同一窗口。', 'maraDeparted=false；没有实际拘捕默认未解。')]
        rr = results(nid, 15, rows, 'harbor')
        harbor_results.extend((nid, i, r) for i, r in enumerate(rr))
    for cid, title in [('captured', '案件结果：克莱拉归案'), ('escaped', '案件结果：克莱拉离港'),
                       ('wrong', '案件结果：错抓吕西安'), ('unresolved', '案件结果：尚未核实真凶责任')]:
        original = source[cid]
        node(cid, 15, title, original['summary'], 'ending', 2, 'harbor',
             effects='保存唯一案件主结果；之后土地、救助与身份判定不回改本结果。',
             notes='案件结果不是玩家身份。错误拘捕与真凶离港同真时，主结果为错抓，另附离港事实。')
    for scene, i, r in harbor_results:
        if i == 0:
            edge(r, 'captured' if scene == 'p06' else 'unresolved', '问询与执行的实际结果')
        elif i in (1, 3, 6):
            edge(r, 'unresolved', '未形成实际拘捕或离港')
        elif i == 2:
            edge(r, 'wrong', '发生错误谋杀拘捕', '已有吕西安偏向、无已核实反证、未核实真凶责任，实际拘捕发生')
            edge(r, 'unresolved', '不能构成错误拘捕', '上述错误拘捕条件未齐备；不得仅凭药效指定错抓')
        else:
            edge(r, 'escaped', '克莱拉实际登船离港', '离开计划已形成，玛拉已走，存在船期窗口，无实际控制')
            edge(r, 'unresolved', '未发生离港或归案', '上述离港条件未齐备')
    restitution_specs = [
        ('p07', '第一批返还：名目写对，钱也要真的到', '已有可用逐户确认，接下来是收据名目与实际支付。几户收到不代表其他家庭全已解决。', '已有可用逐户记录与当事人确认。'),
        ('p07_dispute', '第一批返还：不能拿“感谢”换旧债', '公示或收据仍被写成恩典，部分家庭拒签。更正名目和安排款项各有具体经办人。', '名目存在争议，逐户基础记录仍可用。'),
        ('p07_pending', '第一批返还：先把未确认的家庭列清', '记录不足、邀请未办完或有人不愿接受安排。可以推进已确认部分，不能凭空写出所有人的收据。', '无可用逐户记录，或仍有重大身份、原约缺口。')]
    restitution_results = []
    for nid, title, synopsis, condition in restitution_specs:
        node(nid, 16, title, synopsis, template='restitution', context='案件主结果照旧；埃德蒙的土地责任不会因真凶是谁而消失。',
             options=pair_options('p07') if nid != 'p07_pending' else 'A · 老石匠：把能找到来源的家庭逐户列清。\nB · 玛拉：先为已确认家庭办理款项，未确认者另记。', conditions=condition)
        for case in ('captured', 'escaped', 'wrong', 'unresolved'):
            edge(case, nid, '案件之后仍需处理土地旧债', condition)
        restitution_results.extend(results(nid, 16, [
            ('A1 · 写正已核对的名目', '石匠坚持写成返还旧债；有实际到账回执的家庭才能签收，没有回执的继续单列。缺记录时先列来源，不制作假的收据。', '名目已更正或来源已列清；款项到账读取真实回执，不自动生成。'),
            ('A2 · 为名目争执，交接停下', '他坚持公道却把现场吵散，纸件留住了，交接没有办完。', '名目争议与交接停滞；不抹去原债。'),
            ('A3 · 没能核对完名单', '他只核对部分姓名或停在来源缺口上，不能把全部家庭写成已签收。', 'householdPending；实际已收部分保留。'),
            ('B1 · 已确认家庭实际收到款', '玛拉为有原约来源且本人确认的家庭完成支付，收回逐户凭据。全无可支付对象时只保留预备款，不能把名单补造。', '仅有来源、确认与实际支付的家庭记已到账；其他待办。'),
            ('B2 · 急着付完，安排失衡', '她为图赶紧解决，在数目或先后上发生争议，已转款和未转款分别留下。', '有限款项与争议分别记，不撤销真实到账。'),
            ('B3 · 答应了，钱未交到本人', '她有承诺，却没有完成经办交接或仍缺确认对象。', 'promised≠paid；款项未到账。')], 'restitution'))
    node('p08', 17, '冬季发运：这一趟车先接到哪里', '本期已有一批有来源的物资，当日只能协调一趟车。缝补员想核清冬衣送到孩子手里，伊莱拉想把煤药接到患者身边。先接哪里，另一处的具体等待和短缺也要写进回信。', template='relief',
         context='新增讨论前提：有明确来源的一趟车、已备的一批冬衣或煤药，按所选订单安排目的地。数量与供应成本尚未制定。', options=pair_options('p08'),
         notes='不能因曝光就自动断供，也不因组织改名自动恢复。未选去向本趟尚未签收，已有历史到货照旧。')
    for r in restitution_results:
        edge(r, 'p08', '返还之后，人间仍需过冬', '带着未处理家庭与已到账范围继续')
    shipment = original_results('p08', 'p08', 17, 'relief', ' 只记录所选目的地的真实签收与缺口，未选去向不免费收货。')
    node('closing', 18, '最后的经营收尾：把收到的回信摊开',
         '案件已有结果，土地与救助仍呈现实际进度。玩家继续完成当前路线的订单与家居目标，结束收尾后才收到属于自己的特殊瓶子。', 'merge', template='identity',
         context='回信可以并列：真凶归案但返还未完成，案件未解但病人收到煤药。不能把所有人写成同一种圆满。',
         options='结束经营收尾，按既有资格判定唯一身份；这里不增加破案投票。',
         effects='读取实际订单、家居、库存词条与保存的案件结果。新增订单考核集合与日程待后续接入时确认。')
    for r in shipment:
        edge(r, 'closing', '各自的到货与短缺进入收尾')
    identity_conditions = {
        'apprentice': '固定家居齐备、当前路线全部必需订单及额外接单三星；优先于其他普通身份。新订单集合待重排。',
        'edmund': '未达学徒，且案件正式真凶归案。收到自己的瓶子，无法剪词后确认身份。',
        'nameless': '未达学徒，真凶未归案，未确认个人过去；可用不同词条至少12种、覆盖5类。',
        'unreached': '未达以上条件。能剪埃德蒙的词，再收到自己的完整旧求助记录。',
    }
    for iid, condition in identity_conditions.items():
        original = source[iid]
        node(iid, 20, original['title'], original['summary'], 'ending', template='identity', conditions=condition, effects=original['effects'])
        edge('closing', iid, '唯一身份揭晓', condition)
    node('traveler', 19, '无名旅人：有效票期内主动启程', source['traveler']['summary'], 'ending', template='identity',
         conditions='票期有效且正式货币足够，玩家确认购买并启程；不是拖到普通终局才参与判定。',
         notes='画在结局区便于展示，但实际是经营期间的中断出口。旧第6～11天、300金币需随新日程重新校准，未自动改动。')
    edge('root', 'traveler', '经营期间可提前离场', '仅在票期有效、资金足够且玩家实际确认时；未完成案件另记未解，已有结果保留')
    titles = json.loads((WORKSPACE / 'docs/文案/故事标题表_v01.json').read_text(encoding='utf-8'))['routeNodes']
    original_titles = {n['id']: n['title'] for n in p['nodes']}
    for n in p['nodes']:
        if n['id'] in titles:
            n['title'] = titles[n['id']]
    for e in p['edges']:
        if e['to'] in titles and e['label'] == original_titles[e['to']]:
            e['label'] = titles[e['to']]
    validate(p)
    # Authoring completeness checks, stronger than the editor's editable-draft validation.
    outgoing = {e['from'] for e in p['edges']}
    terminal = set(identity_conditions) | {'traveler'}
    assert all(n['id'] in outgoing or n['id'] in terminal for n in p['nodes'])
    reachable = {'root'}
    for _ in p['nodes']:
        reachable.update(e['to'] for e in p['edges'] if e['from'] in reachable)
    assert len(reachable) == len(p['nodes'])
    return p


if __name__ == '__main__':
    project = build()
    TARGET.parent.mkdir(exist_ok=True)
    TARGET.write_text(json.dumps(project, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(project["nodes"])} nodes; {len(project["edges"])} routes; candidate: {TARGET}')
