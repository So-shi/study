% sun_position.csv は2018/7/1のデータ
% 光子数を計算するスクリプト
% とりあえず、葉モデルは更新せず固定させ、光子数を計算する関数を実装する。


%葉モデルの面の頂点座標を決定

%太陽の動きを15分おきに更新。
%中心座標をプロット
figure;

[x, y, z] = sph2cart(deg2rad(sunposition.Azimuth),deg2rad(sunposition.Elevation),10.0);
plot3(x, y, z, "o")
xlabel("x (east or west)")
ylabel("y (north or south)")
zlabel("z (height)")
grid on;
hold on;



%球の乱数を生成
%figure
for n = 1:2
    rng(0,'twister')
    rvals = 2*rand(100,1)-1;
    elevation = asin(rvals);

    azimuth = 2*pi*rand(100,1);
    radii = 1*(rand(100,1).^(1/3));
    [x_rand,y_rand,z_rand] = sph2cart(azimuth,elevation,radii);
    plot3(x_rand + x(n), y_rand + y(n), z_rand + z(n),'.')
    hold on
    
    %乱数で生成した点の直線の描画
    direction_vector = [x(n), y(n), z(n)];   %方向ベクトルの保持
    y_tmp = line_xz(x_rand, z_rand);
    disp(direction_vector);
    
end

function y = line_xz(x, z)
   y = x+z;
end

%模擬放射光源の作成（試作段階）
%ネットから。没かな？
%{
figure
for n = 1:63
    point = [x(n), y(n), z(n)];
    normal = point; 
    %# a plane is a*x+b*y+c*z+d=0
    %# [a,b,c] is the normal. Thus, we have to calculate
    %# d and we're set
    d = -point*normal'; %'# dot product for less typing

    %# create x,y
    [xx,yy]=ndgrid(1:10,1:10);

    %# calculate corresponding z
    zz = (-normal(1)*xx - normal(2)*yy - d)/normal(3);
    
    surf(xx,yy,zz)
    
    grid on
    hold on
end
%}

%模擬放射光源の作成（試作段階）
%meshgridを用いた方法。没かな？
%{
for n = 10:40
    [x_range,y_range]=meshgrid(x(n)-1:0.1:x(n)+1,y(n)-1:0.1:y(n)+1);
    z_range = ((x(n).^2 + y(n).^2 + z(n).^2 - x(n)*x_range - y(n)*y_range) / z(n));
    
    surf(x_range, y_range, z_range);
    hold on;
    
end
plot3(0, 0, 0, "o");
%}
