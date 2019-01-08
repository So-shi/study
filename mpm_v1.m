%{  
    2018/12/21
    一時的なスクリプト。のちのち、全て関数化。
    
%}
M = 11;     %max_depth
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
Tree.surface = [];  %面の情報
Tree.default = {m_lam, s_lam, m_ab, s_ab};  %各パラメータの平均と分散
Tree.branch = [];     %Fのとき長さのパラメータ
Tree.a = [];          %x軸の角度のパラメータ（R）
Tree.b = [];          %   、、           （L）
Tree.c = [];          %z軸の角度のパラメータ（+）
Tree.d = [];          %   、、           （-）

Tree = ini(Tree, 3);        %文字列とパラメータの初期化
%Tree = add_surface(Tree);   %生成された文字列、パラメータを用いて葉の面積を付加する処理
%Tree = mpm(Tree);
%ここに3dスペースへ描画の処理を
treePlot(Tree);     %Treeをプロット




%%%%%%%%%%%%%%%%%%%以下関数%%%%%%%%%%%%%%%%%%%%

%   Metropolis Procedural Modeling
%   入力はTree、出力はTree
function Tree = mpm(Tree)
N = 10;     %最適化回数
for i = 1:N
    tmp = diffusion_or_jump;
    switch tmp
        case 'diffusion'
            t = random_terminal(Tree);  %Treeの中の文字列の終端記号をランダムに
            %disp("選ばれたインデックス番号とその文字:" + t + "と" + Tree.str(t));
            param = sample_diffusion(Tree, t);  %選ばれた終端記号に対して再サンプリング
            accept_pro = likehood_diffusion(Tree, param);   %採択確率、尤度関数
        case 'jump'
            %ここはゆくゆく
    end
    t = rand(1);
    if t < accept_pro
        Tree = copy_parme_tree(Tree, param);
    else
        
    end
    
end
end

%   difussionかjumpの文字列を返す関数
%   確率はjumpの方が大きくする予定
function tmp = diffusion_or_jump

tmp = 'diffusion';  %一時的なやつ
end

%   終端記号をランダムに返す関数
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

%   一時的なやつ。Treeの初期化。Tree.strに適当に文字列を
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
            %l = 0.4;
            
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
end

Tree.str = axiom;   %初期文字列のセット

%   パラメータの初期値を設定
%   Tree.paramは一応つくった。
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

%   Treeの内容をプロットする関数
%   2019/1/8に気づく。前半と後半の処理を別の関数に分けた方が良いのでは？
function treePlot(Tree)
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
end
%   生成された文字列、パラメータを用いて葉の面積を付加する関数
function add_surface(Tree)



end
