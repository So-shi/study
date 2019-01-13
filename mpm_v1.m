%{  
    2018/12/21
    一時的なスクリプト。のちのち、全て関数化。
    
%}
M = 3;     %max_depth
m_lam = 0.5;    %枝のパラーメタの平均
s_lam = 0.2;    %   、、　　　　分散
m_ab = pi/6;
s_ab = pi/18;
%{
m_a = pi/6;
s_a = pi / 18;
m_b = 0;
s_b = pi/18;
%}
Tree.str = [];      %(X 1 <subtree>)生成済みの文字列
Tree.str_log = [];  %文字列の履歴
Tree.surface = [];  %面の情報
Tree.T = [];        %プロットのための情報
Tree.default = {m_lam, s_lam, m_ab, s_ab};  %各パラメータの平均と分散
Tree.branch = [];     %Fのとき長さのパラメータ
Tree.a = [];          %x軸の角度のパラメータ（R）
Tree.b = [];          %   、、           （L）
Tree.c = [];          %z軸の角度のパラメータ（+）
Tree.d = [];          %   、、           （-）
Tree.param = [];      %全てのパラメータ　結局、上のabcdは使わずにこっち使う。

Tree = ini(Tree, M);        %文字列とパラメータの初期化 第二引数は何回置換するか
Tree = add_info(Tree);      %描画や誘導関数計算のために、パラメータに対してのプロット情報や葉の情報
%treePlot(Tree);
Tree = mpm(Tree);
%ここに3dスペースへ描画の処理を





%%%%%%%%%%%%%%%%%%%以下関数%%%%%%%%%%%%%%%%%%%%

%   Metropolis Procedural Modeling
%   入力は初期化されたTree、出力は最適化されたTree
function Tree = mpm(Tree)
N = 20;     %最適化回数
for i = 1:N
    tmp = diffusion_or_jump;
    switch tmp
        case 'diffusion'
            t = random_terminal(Tree);  %Treeの中の文字列の終端記号をランダムに
            %disp("選ばれたインデックス番号とその文字:" + t + "と" + Tree.str(t));
            param = resample_diffusion(Tree, t);  %選ばれた終端記号インデックスに対して再サンプリング
            accept_pro = likehood_diffusion(Tree, param, t);   %採択確率、尤度関数
        case 'jump'
            copy_tree = Tree;
            %Treeの非終端記号をランダムに選び出す(v = [str_logのインデックス, 文字のインデックス])
            v = random_nonterminal(copy_tree);
            copy_tree = rederive_tree(copy_tree, v);  %選ばれたvに対して再派生
            copy_tree = dimensionmatch(Tree, copy_tree, v);   %パラメータの次元を合わせる
            accept_pro = likehood_jump();
    end
    rnd = rand(1);
    if rnd < accept_pro
        switch tmp
            case 'diffusion'
                %パラメータの更新
                Tree.param(t) = param;
            case 'jump'
                Tree.str = copy_tree.str;
                Tree.param = copy_tree.param;
        end
    end
    Tree = add_info(Tree);  %パラメータを更新したので、プロット情報や面の情報も更新
    treePlot(Tree); 
end
end

%   difussionかjumpの文字列を返す関数
%   確率はjumpの方が大きくする予定
function tmp = diffusion_or_jump
rnd = rand(1);
if rnd >= 0
    tmp = 'diffusion';
else
    tmp = 'jump';
end
end


%%%%%%%%%%%%%%%%%%  diffusion用　　%%%%%%%%%%%%%%%%%%%

%   終端記号をランダムに返す関数(diffusion用)
%   入力はTree、出力はt（Tree.strの最新の文字列の中での終端記号のインデックス番号）。
function t = random_terminal(Tree)
%str = Tree.str(length(Tree.str));  %今は1×1だから下のでいいが、Tree.strが増えれば
str = Tree.str;      %strに対象の文字列をコピー
n = randi([1 length(Tree.str)], 1);

while(1)
    if str(n) == 'F' || str(n) == 'L' || str(n) == 'R' || str(n) == '+' || str(n) == '-'
        t = n;  %インデックスを返す
        break;
    else        %終端文字列じゃない場合、ランダムに
        tmp = rand;
        if n == length(str)
            n = n-1;
        elseif n == 1
            n = n+1;
        else
            if tmp >= 0.5
                n = n+1;
            else
                n = n-1;
            end
        end
    end        
end
end

%   引数t(終端記号のインデックス)に対して、パラメータを際割り当てする関数(diffusion用)
function param = resample_diffusion(Tree, t)
switch Tree.str(t)
    case 'F'
        param = normrnd(Tree.default{1}, Tree.default{2});
    case 'R'
        param = normrnd(Tree.default{3}, Tree.default{4});
    case 'L'
        param = normrnd(Tree.default{3}, Tree.default{4});
    case '+'
        param = normrnd(Tree.default{3}, Tree.default{4});
    case '-'
        param = normrnd(Tree.default{3}, Tree.default{4});
    otherwise
        disp("error");
        return
end
end

%   tとparamに対しての採択確率を返す関数(diffusion用)
%   尤度関数や！
function accept_pro = likehood_diffusion(Tree, param, t)
now_quanta = light_quanta_calu(Tree.surface);   %比較前の状態で光子数の計算
Tree.param(t) = param;
Tree = add_info(Tree);
next_quanta = light_quanta_calu(Tree.surface);  %比較する状態の光子数の計算

now_likehood = -(standard_likehood - now_quanta).^2;
next_likehood = -(standard_likehood - next_quanta).^2;

accept_tmp = (next_likehood / now_likehood);

if 1 < accept_tmp
    accept_pro = 1;
else
    accept_pro = accept_tmp;
end
disp(accept_pro);
end


%%%%%%%%%%%%%%%%%  jump用  %%%%%%%%%%%%%%%%%

%   非終端記号をランダムに返す関数(jump用)
%   Tree.str_logの履歴の中からランダムに選択したあと、その文字列の中からランダムな
%   非終端記号を返す v=[Tree.str_logのインデックス, その文字列から選出された文字のインデックス]
function v = random_nonterminal(copy_tree)
i = randi(length(copy_tree.str_log)-1);   %最後の履歴は非終端記号が含まれないので

str = char(copy_tree.str_log(i));       %cell配列から文字ベクトルへ変換
candidate_index = [];   %候補となるインデックスを格納する配列
for n=1:length(str)
    if str(n) == 'X'
        candidate_index = [candidate_index, n];
    end   
end
%   ここエラー出る。candidate_indexの長さが0のときがあるから。のちのち。
tmp = randi(length(candidate_index));

v = [i, candidate_index(tmp)];
end

%    ランダムで選ばれたvに対して、そのサブツリーvを再派生する関数
function copy_tree = rederive_tree(copy_tree, v)
str = copy_tree.str_log(v(1));
str = char(str);

rule(1).before = 'X';
rule(1).after = 'F[LX][RX][+X][-X]';

rule(2).before = 'X';
rule(2).after = 'FZ';

axiom = str(v(2));
nReps = 4;  %最大置換回数の値。関数外にあるM(最大置換回数)をグローバルに使えるように
disp("copy_tree.str:::"+copy_tree.str)
disp("置換する文字列:::"+copy_tree.str_log(v(1))+"の"+v(2)+"番目")
for i=v(1)+1:nReps
    %one character/cell, with indexes the same as original axiom string
    axiomINcells = cellstr(axiom'); 
    
    hit = strfind(axiom, rule(1).before);
    
    if length(hit) >= 1
        for k = hit
            l = rand;   
            %l = 0.8;   %ここを固定にすると、毎回同じ分岐をした木が形成される。
            if (l < i/nReps) && (length(axiomINcells)>=1)
                axiomINcells{k} = rule(2).after;
            else
                axiomINcells{k} = rule(1).after;
            end
            %axiomINcells{k} = rule(1).after;
        end
    end
    
    %cell配列を文字ベクトルに直す
    axiom = [];
    for j=1:length(axiomINcells)
        axiom = [axiom, axiomINcells{j}];
    end
    disp(axiom)
end

end

function copy_tree = dimensionmatch(Tree, copy_tree, v)


end

%%%%%%%%%%%%%%%%%%%%  以下共通　　%%%%%%%%%%%%%%%%%%%%

%   Treeの初期化。Treeに文字列とパラメータを格納
%   改善の余地　→ 毎回ランダムになるので固定にしたい？？？
function Tree = ini(Tree, N)
rule(1).before = 'X';
rule(1).after = 'F[LX][RX][+X][-X]';

rule(2).before = 'X';
rule(2).after = 'FZ';

%nRules = length(rule);

%starting seed 初期文字列
axiom = 'X';

%number of repititions
nReps = N;


for i=1:nReps
    %len = len*ratio;
    
    %one character/cell, with indexes the same as original axiom string
    axiomINcells = cellstr(axiom'); 
    
    hit = strfind(axiom, rule(1).before);
    
    if length(hit) >= 1
        for k = hit
            l = rand;   
            %l = 0.8;   %ここを固定にすると、毎回同じ分岐をした木が形成される。
            
            if (l < i/nReps) && (length(axiomINcells)>1)
                axiomINcells{k} = rule(2).after;
            else
                axiomINcells{k} = rule(1).after;
            end
            %axiomINcells{k} = rule(1).after;
        end
    end
    
    %now convert individual cells back to a string
    axiom=[];
    for j=1:length(axiomINcells)
        axiom = [axiom, axiomINcells{j}];
    end
    %   履歴を保存
    tmp_str = cellstr(axiom);
    Tree.str_log = [Tree.str_log; tmp_str];
end

Tree.str = axiom;   %初期文字列のセット

%   パラメータの初期値を設定
for i = 1:length(Tree.str)
    switch Tree.str(i)
        case 'F'
            param = normrnd(Tree.default{1}, Tree.default{2});
            Tree.branch = [Tree.branch, param];
            Tree.param(i) = param;
        case 'R'
            param = normrnd(Tree.default{3}, Tree.default{4});
            Tree.a = [Tree.a, param];
            Tree.param(i) = param;
        case 'L'
            param = normrnd(Tree.default{3}, Tree.default{4});
            Tree.b = [Tree.b, param];
            Tree.param(i) = param;
        case '+'
            param = normrnd(Tree.default{3}, Tree.default{4});
            Tree.c = [Tree.c, param];
            Tree.param(i) = param;
        case '-'
            param = normrnd(Tree.default{3}, Tree.default{4});
            Tree.d = [Tree.d, param];
            Tree.param(i) = param;
        otherwise
            Tree.param(i) = -1;
    end
end
end

%   パラメータに対して、葉の情報とプロットに必要な情報を付加する関数
function Tree = add_info(Tree)
v = [0 0 0];
depth = 1;
stkIndex = 1;
T = [0, 0, 0];
Tree.surface = [];
azimuth = pi/2; elevation = pi/2;
xT = 0; yT = 0; zT =0;
for i = 1:length(Tree.str)
    switch Tree.str(i)
        case 'F'
            
            [newxT, newyT, newzT] = sph2cart(azimuth, elevation, Tree.param(i));
            xT = xT+newxT; yT = yT+newyT; zT = zT+newzT;
            T = [T; xT, yT, zT];
            %disp(i)
            %disp(T)
            %v = [v, azimuth, elevation, Tree.param(i)];
        case 'R'
            azimuth = 0;
            elevation = Tree.param(i);
            
        case 'L'
            azimuth = pi;
            elevation = Tree.param(i);
        case '+'
            azimuth = pi/2;
            elevation = Tree.param(i);
        case '-'
            azimuth = pi * 3/2;
            elevation = Tree.param(i);
        case '['
            stack(stkIndex).xT = xT;
            stack(stkIndex).yT = yT;
            stack(stkIndex).zT = zT;
            stkIndex = stkIndex + 1;
            depth = depth + 1;
        case ']'
            stkIndex = stkIndex - 1;
            xT = stack(stkIndex).xT;
            yT = stack(stkIndex).yT;
            zT = stack(stkIndex).zT;
            T = [T; xT, yT, zT];
            
        case 'Z'
            %3×4行の葉である面の情報を付加
            Tree.surface = [Tree.surface; xT-0.1 yT zT; xT+0.1 yT zT;...
                xT-0.1 yT+0.1 zT+0.1; xT+0.1 yT+0.1 zT+0.1];
        otherwise
            disp("error");
            return
    end    
end
Tree.T = T;
end

%   Treeの内容をプロットする関数
%   add_infoで更新されたあとに実行すること
function treePlot(Tree)
%   Tの内容を描画
%disp("Tの長さ"+length(Tree.T))
%assignin('base', 'Tree.T', Tree.T)
%disp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
figure(1);

for i = 2:length(Tree.T)
    
    plot3([Tree.T(i-1, 1), Tree.T(i, 1)],[Tree.T(i-1, 2), Tree.T(i, 2)],...
        [Tree.T(i-1, 3), Tree.T(i, 3)], 'g', 'Linewidth', 2);
    hold on;
end
%disp(Tree.T);

%   Tree.surface、面の描画
for i = 4:4:length(Tree.surface)
    surf_x = [Tree.surface(i-3, 1) Tree.surface(i-2, 1);...
        Tree.surface(i-1, 1) Tree.surface(i, 1)];
    surf_y = [Tree.surface(i-3, 2) Tree.surface(i-2, 2);...
        Tree.surface(i-1, 2) Tree.surface(i, 2)];
    surf_z = [Tree.surface(i-3, 3) Tree.surface(i-2, 3);...
        Tree.surface(i-1, 3) Tree.surface(i, 3)];
    surf(surf_x, surf_y, surf_z);
    hold on;
end

xlabel("x");
ylabel("y");
zlabel("z");
hold off
end
%{
%   Treeの内容をプロットする関数

function Tree = treePlot(Tree)
%   それぞれ初期化
v = [0 0 0];
depth = 1;
stkIndex = 1;
T = [0, 0, 0];
azimuth = pi/2; elevation = pi/2;
xT = 0; yT = 0; zT =0;
for i = 1:length(Tree.str)
    switch Tree.str(i)
        case 'F'
            
            [newxT, newyT, newzT] = sph2cart(azimuth, elevation, Tree.param(i));
            xT = xT+newxT; yT = yT+newyT; zT = zT+newzT;
            T = [T; xT, yT, zT];
            %disp(i)
            %disp(T)
            %v = [v, azimuth, elevation, Tree.param(i)];
        case 'R'
            azimuth = 0;
            elevation = Tree.param(i);
            
        case 'L'
            azimuth = pi;
            elevation = Tree.param(i);
        case '+'
            azimuth = pi/2;
            elevation = Tree.param(i);
        case '-'
            azimuth = pi * 3/2;
            elevation = Tree.param(i);
        case '['
            stack(stkIndex).xT = xT;
            stack(stkIndex).yT = yT;
            stack(stkIndex).zT = zT;
            stkIndex = stkIndex + 1;
            depth = depth + 1;
        case ']'
            stkIndex = stkIndex - 1;
            xT = stack(stkIndex).xT;
            yT = stack(stkIndex).yT;
            zT = stack(stkIndex).zT;
            T = [T; xT, yT, zT];
            
        case 'Z'
            %3×4行の葉である面の情報を付加
            Tree.surface = [Tree.surface; xT-0.1 yT zT; xT+0.1 yT zT;...
                xT-0.1 yT+0.1 zT+0.1; xT+0.1 yT+0.1 zT+0.1];
        otherwise
            disp("error");
            return
    end    
end

%   Tの内容を描画
%disp("Tの長さ"+length(T))
assignin('base', 'T', T)
%disp("%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
figure(1);
for i = 2:length(T)
    
    plot3([T(i-1, 1), T(i, 1)],[T(i-1, 2), T(i, 2)],[T(i-1, 3), T(i, 3)], ...
        'g', 'Linewidth', 2);
    hold on
end
assignin('base', 'T', T)
%disp(T);

%   Tree.surface、面の描画
for i = 4:4:length(Tree.surface)
    surf_x = [Tree.surface(i-3, 1) Tree.surface(i-2, 1);...
        Tree.surface(i-1, 1) Tree.surface(i, 1)];
    surf_y = [Tree.surface(i-3, 2) Tree.surface(i-2, 2);...
        Tree.surface(i-1, 2) Tree.surface(i, 2)];
    surf_z = [Tree.surface(i-3, 3) Tree.surface(i-2, 3);...
        Tree.surface(i-1, 3) Tree.surface(i, 3)];
    surf(surf_x, surf_y, surf_z);
    hold on 
end
xlabel("x");
ylabel("y");
zlabel("z");
end
%}
