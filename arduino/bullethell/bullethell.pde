// Bullet hell game for Arduino coursework
// Created by Walter Wu on 28/10/17
//
//
// Following library is used in this program:
// Title: Firmata library for Processing
// Author: soundanalogous
// Date: 8 Nov 2016
// Availabile at https://github.com/firmata/processing/releases/tag/latest
//
// Title: SQLibrary
// Author: fjenett
// Date: 11 Apr 2013
// Avaliable at https://github.com/fjenett/sql-library-processing/releases

import processing.serial.*;
import cc.arduino.*;
import de.bezier.data.sql.*;

Arduino ard;
Player player;
Enemy enemy;
GameStatus game;
Boolean uploaded;
int score, delayCounter;
ArduinoStatus status;
MySQL db;
String name;

final int LEFT_IN_PIN = 7;
final int RIGHT_IN_PIN = 8;
final int PLAYER_MOVE_SPEED = 5;
final int PLAYER_SIZE = 30;
final int ENEMY_SIZE = 20;
final int ENEMY_MOVE_SPEED = 2;
final int ENEMY_MOVE_DELAY = 100;
final int ENEMY_SHOOT_DELAY = 60;
final int BULLET_NUM = 15;
final int BULLET_SIZE = 20;
final Colour PINK = new Colour(247, 134, 244);
final Colour GREEN = new Colour(117, 237, 138);
final Colour CYAN = new Colour(117, 237, 230);
final Colour YELLOW = new Colour(210, 247, 62);
final Colour RED = new Colour(250, 61, 61);
final Colour BLUE = new Colour(61, 77, 250);
final String DBHOST = "eu-cdbr-azure-west-b.cloudapp.net";
final String DBUSER = "bcf74a4a937449";
final String DBPASS = "fb35064177cf9e0";
final String DBNAME = "arduinocoursework";


void setup() {
  size(1600, 1200);
  background(0);
  noStroke();
  if (ard == null) {
    ard = new Arduino(this, Arduino.list()[0], 57600);
  }
  ard.pinMode(LEFT_IN_PIN, ard.INPUT);
  ard.pinMode(RIGHT_IN_PIN, ard.INPUT);
  status = ArduinoStatus.untilted;
  player = new Player();
  enemy = new Enemy();
  score = 0;
  game = GameStatus.proceeding;
  name = "";
  delayCounter = 0;
}

void draw() {
  if (game == GameStatus.proceeding) {
    background(0);
    player.draw();
    enemy.draw();

    // update arduino status
    if (ard.digitalRead(LEFT_IN_PIN) == 1 && status != ArduinoStatus.left_tilted) {
      status = ArduinoStatus.left_tilted;
    } else if (ard.digitalRead(RIGHT_IN_PIN) == 1 && status != ArduinoStatus.right_tilted) {
      status = ArduinoStatus.right_tilted;
    } else if (ard.digitalRead(LEFT_IN_PIN) == 0 && ard.digitalRead(RIGHT_IN_PIN) == 0 && status != ArduinoStatus.untilted) {
      status = ArduinoStatus.untilted;
    }

    score += 1;
    fill(255);
    textSize(30);
    textAlign(LEFT);
    text("Score: " + nf(score, 8), width / 16, height / 12);

    if (enemy.ifHit(player.getx(), player.gety())) {
      game = GameStatus.over;
    }
  } else if (game == GameStatus.over) {
    fill(175);
    textSize(80);
    textAlign(CENTER);
    text("GAME OVER", width / 2, height / 2 - 50);
    textSize(40);
    text("Your Score: " + nf(score, 8), width / 2, height / 2);
    text("Press Enter to Restart", width / 2, height / 2 + 50);
    text("Press Space to Upload Your Score to Scoreboard", width / 2, height / 2 + 100);
    if (keyPressed && key == ENTER) {
      setup();
    } else if (keyPressed && key == ' ') {
      game = GameStatus.inputing;
    }
  } else if (game == GameStatus.inputing) {
    fill(200);
    background(0);
    textSize(40);
    textAlign(LEFT);
    text("Please enter your name (letters, numbers and spaces only):", width / 12, height / 8);
    text(name, width / 12, height / 8 + 60);
  } else if (game == GameStatus.uploading) {
    background(0);
    fill(200);
    textSize(80);
    textAlign(CENTER);
    if (uploaded) {
      text("Upload sucess!", width / 2, height / 2 - 50);
    } else {
      text("Unable to connect to database!", width / 2, height / 2 - 50);
    }
    delayCounter += 1;
    if (delayCounter >= 120) {
      setup();
    }
  }
}

void keyReleased() {
  // read user inpput for name
  if (game == GameStatus.inputing) {
    if (key == ENTER) {
      game = GameStatus.uploading;
      uploaded = upload();
    } else if (key == BACKSPACE) {
      if (name.length() > 0) {
        name = name.substring(0, name.length() - 1);
      }
    } else if ((key >= '0' && key <= '9') || (key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') || key == ' ') {
      // ensure length of name does not exceed limit of database column
      if (name.length() < 50) {
        name += str(key);
      }
    }
  }
}

Boolean upload() {
  int ranking = 1;
  Boolean foundPosition = false;
  db = new MySQL(this, DBHOST, DBNAME, DBUSER, DBPASS);
  if (db.connect()) {
    db.query("SELECT * FROM scoreboard ORDER BY rank");
    while (db.next () && foundPosition == false) {
      if (int(db.getString("score")) < score) {
        // inserting position found
        ranking = int(db.getString("rank"));
        foundPosition = true;
      }
      if (foundPosition) {
        // input score with right ranking, then increment rankings of lower scores
        db.query("UPDATE scoreboard SET rank = rank + 1 WHERE rank >= " + str(ranking));
        db.query("INSERT INTO scoreboard (rank, score, name) VALUES(" + str(ranking) + ", " + str(score) + ", \" " + name + " \")");
      }
    }

    // postion not found -- either ranking at last place or table is empty
    if (!foundPosition) {
      db.query("SELECT * FROM scoreboard");
      if (db.next()) {
        // if table is not empty -- rank = max rank + 1
        db.query("SELECT MAX(rank) FROM scoreboard");
        db.next();
        ranking = int(db.getString("MAX(rank)")) + 1;
      }
      db.query("INSERT INTO scoreboard (rank, score, name) VALUES(" + str(ranking) + ", " + str(score) + ", \" " + name + " \")");
    }
    return true;
  }
  // unable to connect to database
  return false;
}



class SpaceShip {
  int x, y;

  void draw() {
    update();
    drawShip();
  }

  void update() {
  }
  void drawShip() {
  }
}

class Player extends SpaceShip {
  Player() {
    x = width / 2;
    y = height - 50;
  }

  void update() {
    // Arduino control
    if (status == ArduinoStatus.left_tilted) {
      x -= PLAYER_MOVE_SPEED;
    } else if (status == ArduinoStatus.right_tilted) {
      x += PLAYER_MOVE_SPEED;
    }
    // keyboard control:
    if (keyPressed && keyCode == LEFT && x > 80) {
      x -= PLAYER_MOVE_SPEED;
    }
    if (keyPressed && keyCode == RIGHT && x < width - 80) {
      x += PLAYER_MOVE_SPEED;
    }
  }

  void drawShip() {
    fill(RED.getR(), RED.getG(), RED.getB());
    ellipse(x, y, PLAYER_SIZE, PLAYER_SIZE);
  }

  int getx() {
    return x;
  }
  int gety() {
    return y;
  }
}


class Enemy extends SpaceShip {
  // for enemy, x,y will be bottom point of triangle
  boolean hasTarget = false;
  boolean canMove = false;
  int targetx = 0, delayCount = 0, colourCode = 0;
  ArrayList bullets = new ArrayList();

  Enemy() {
    x = width / 2;
    y = 100;
  }

  void update() {
    // update status for both bullets and enemy
    updateBullets();
    if (frameCount % ENEMY_SHOOT_DELAY == 0 || frameCount == 1) {
      shoot();
    }
    moveEnemy();
  }

  void drawShip() {
    fill(BLUE.getR(), BLUE.getG(), BLUE.getB());
    triangle(x, y, x - 2 * ENEMY_SIZE, y - 3 * ENEMY_SIZE, x + 2 * ENEMY_SIZE, y - 3 * ENEMY_SIZE);
  }

  void updateBullets() {

    // remove the bullets that are out of screen
    for (int i = 0; i < bullets.size (); i++) {
      Bullet bInstance = (Bullet) bullets.get(i);
      if (!bInstance.checkValidity()) {
        bullets.remove(i);
      }
    }
    for (int i = 0; i < bullets.size (); i++) {
      Bullet bInstance = (Bullet) bullets.get(i);
      bInstance.draw();
    }
  }

  void moveEnemy() {
    // if can move, move enemy towards chosen target, or select new target
    if (!canMove) {
      delayCount++;
      if (delayCount >= ENEMY_MOVE_DELAY) {
        delayCount = 0;
        canMove = true;
      }
      return;
    }
    hasTarget = (abs(targetx - x) > ENEMY_MOVE_SPEED) && (targetx != 0);
    if (!hasTarget) {
      targetx = findTargetx(targetx);
      hasTarget = true;
      canMove = false;
      return;
    }
    if (targetx > x) {
      x += ENEMY_MOVE_SPEED;
    } else if (targetx < x) {
      x -= ENEMY_MOVE_SPEED;
    }
  }

  int findTargetx(int previousX) {
    // ensure next target point is far away from last one
    if (targetx < 800) {
      return int(random(1000, 1100));
    } else {
      return int(random(500, 600));
    }
  }

  void shoot() {
    Colour bulletColour;
    // use colourCode to select different colours for bullets
    switch ((colourCode++) % 4) {
    case 0:
      bulletColour = PINK;
      break;
    case 1:
      bulletColour = GREEN;
      break;
    case 2:
      bulletColour = CYAN;
      break;
    case 3:
      bulletColour = YELLOW;
      break;
    default:
      bulletColour = PINK;
      break;
    }

    for (int i = 0; i < BULLET_NUM; i++) {
      bullets.add(new Bullet(float(x), float(y), random(-10, 10), random(17, 19), bulletColour.getR(), bulletColour.getG(), bulletColour.getB()));
    }
  }

  boolean ifHit(int playerx, int playery) {
    for (int i = 0; i < bullets.size (); i++) {
      Bullet bInstance = (Bullet) bullets.get(i);
      if (bInstance.ifHit(playerx, playery)) {
        return true;
      }
    }
    return false;
  }
}


class Bullet {
  float x, y, xSpeed, ySpeed;
  int r, g, b;

  Bullet(float startx, float starty, float xspeed, float yspeed, int colourR, int colourG, int colourB) {
    x = startx;
    y = starty;
    xSpeed = xspeed;
    ySpeed = yspeed;
    r = colourR;
    g = colourG;
    b = colourB;
  }

  void draw() {
    update();
    drawBullet();
  }

  void update() {
    x += xSpeed;
    y += ySpeed;
    // reduce yspeed
    if (ySpeed > 2) {
      if (y >= height * 4 / 5) {
        ySpeed = ySpeed * 0.9;
        xSpeed = xSpeed * 0.95;
      }
    }
  }

  void drawBullet() {
    fill(r, g, b);
    ellipse(int(x), int(y), BULLET_SIZE, BULLET_SIZE);
  }

  boolean checkValidity() {
    if (x < -(BULLET_SIZE / 2) || x > width + BULLET_SIZE / 2 || y < -(BULLET_SIZE / 2) || y > height + BULLET_SIZE / 2) {
      // bullet has left range of screen
      return false;
    }
    return true;
  }

  boolean ifHit(int playerx, int playery) {
    float distSqr = sq(x - float(playerx)) + sq(y - float(playery));
    // when distance is less than sum of radius -> hit
    if (distSqr < sq(float(PLAYER_SIZE + BULLET_SIZE) / 2)) {
      return true;
    }
    return false;
  }
}


class Colour {
  int R, G, B;

  Colour(int r, int g, int b) {
    R = r;
    G = g;
    B = b;
  }

  int getR() {
    return R;
  }

  int getG() {
    return G;
  }

  int getB() {
    return B;
  }
}

